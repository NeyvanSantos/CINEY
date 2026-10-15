package com.example.castlite

import android.content.Context
import android.util.Log
import android.webkit.CookieManager
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.URL
import java.net.URI
import java.nio.charset.StandardCharsets
import java.util.Collections
import java.util.Locale
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread

/**
 * A short-lived LAN HTTP relay so a Cast receiver can fetch media using the
 * browser's cookies/referer/user-agent. Range requests are forwarded unchanged.
 * The random route token is generated per load and is never persisted.
 */
class LocalMediaProxy(context: Context) : Closeable {
    internal var frameTransport: FrameMediaTransport? = null
    private data class Resource(val url: String, val mimeType: String? = null, val variantQuality: String? = null)
    private data class Route(
        val token: String,
        val host: String,
        val port: Int,
        val pageUrl: String,
        val requestHeaders: Map<String, String>,
        val userAgent: String,
        val economy: Boolean,
        val resources: ConcurrentHashMap<String, Resource> = ConcurrentHashMap(),
        val lastRequestedVariant: AtomicReference<String?> = AtomicReference(null)
    )

    private val appContext = context.applicationContext
    var economyMode = context.getSharedPreferences("casting", Context.MODE_PRIVATE).getBoolean("economy", true)
    private val routes = ConcurrentHashMap<String, Route>()
    private val serverLock = Any()
    @Volatile private var server: ServerSocket? = null
    @Volatile private var workers: ExecutorService? = null

    /** Returns null when the phone is not on a private IPv4 LAN or the listener cannot start. */
    fun createMediaUrl(video: DetectedVideo, fallbackUserAgent: String): String? {
        val lanAddress = findPrivateIpv4() ?: return null
        return try {
            val listening = ensureServer()
            val token = UUID.randomUUID().toString().replace("-", "")
            val route = Route(
                token = token,
                economy = economyMode,
                host = lanAddress,
                port = listening.localPort,
                pageUrl = video.pageUrl,
                requestHeaders = video.requestHeaders,
                userAgent = video.requestHeaders.entries.firstOrNull {
                    it.key.equals("User-Agent", ignoreCase = true)
                }?.value?.takeIf { it.isNotBlank() } ?: fallbackUserAgent
            )
            route.resources["source"] = Resource(video.url, video.mimeType)
            routes[token] = route
            "http://${route.host}:${route.port}/$token/source"
        } catch (_: Exception) {
            null
        }
    }

    private fun ensureServer(): ServerSocket = synchronized(serverLock) {
        server?.takeIf { !it.isClosed }?.let { return it }
        val listening = ServerSocket().apply {
            reuseAddress = true
            bind(InetSocketAddress("0.0.0.0", 0), 32)
        }
        server = listening
        workers = Executors.newFixedThreadPool(8) { runnable ->
            Thread(runnable, "CastLite-media-proxy-worker").apply { isDaemon = true }
        }
        thread(name = "CastLite-media-proxy", isDaemon = true) {
            while (!listening.isClosed) {
                try {
                    val client = listening.accept()
                    workers?.execute { handle(client) } ?: client.close()
                } catch (_: Exception) {
                    if (!listening.isClosed) Thread.sleep(100)
                }
            }
        }
        listening
    }

    private fun handle(client: java.net.Socket) {
        client.use { socket ->
            try {
                socket.soTimeout = 60_000
                val input = BufferedInputStream(socket.getInputStream())
                val output = BufferedOutputStream(socket.getOutputStream())
                val reader = input.bufferedReader(StandardCharsets.ISO_8859_1)
                val requestLine = reader.readLine() ?: return
                val parts = requestLine.split(' ', limit = 3)
                if (parts.size < 2) return
                val method = parts[0].uppercase(Locale.ROOT)
                val requestTarget = parts[1]
                val headers = HashMap<String, String>()
                var count = 0
                while (count++ < 100) {
                    val line = reader.readLine() ?: break
                    if (line.isEmpty()) break
                    val colon = line.indexOf(':')
                    if (colon > 0) headers[line.substring(0, colon).trim().lowercase(Locale.ROOT)] = line.substring(colon + 1).trim()
                }
                if (method == "OPTIONS") {
                    writeResponse(output, 204, "No Content", emptyMap(), null, method == "HEAD")
                    return
                }
                if (method != "GET" && method != "HEAD") {
                    writeResponse(output, 405, "Method Not Allowed", mapOf("Allow" to "GET, HEAD, OPTIONS"), "Method not allowed".toByteArray(), false)
                    return
                }
                val path = try { URI(requestTarget).rawPath ?: requestTarget.substringBefore('?') } catch (_: Exception) { requestTarget.substringBefore('?') }
                val segments = path.split('/').filter { it.isNotEmpty() }
                if (segments.size != 2) {
                    writeResponse(output, 404, "Not Found", emptyMap(), "Not found".toByteArray(), method == "HEAD")
                    return
                }
                val route = routes[segments[0]]
                val resource = route?.resources?.get(segments[1])
                if (route == null || resource == null) {
                    writeResponse(output, 404, "Not Found", emptyMap(), "Not found".toByteArray(), method == "HEAD")
                    return
                }
                proxyRequest(route, resource, headers, method, output)
            } catch (_: Exception) {
                // The receiver may cancel a range request when playback changes; close quietly.
            }
        }
    }

    private fun proxyRequest(
        route: Route,
        resource: Resource,
        receiverHeaders: Map<String, String>,
        method: String,
        output: BufferedOutputStream
    ) {
        val requestStartedNanos = System.nanoTime()
        val hlsSource = route.resources["source"]?.mimeType.orEmpty().contains("mpegurl", true)
        val playlistResource = HlsPlaylist.isPlaylist(resource.url, null, resource.mimeType)
        var responseStarted = false
        if (method == "GET") {
            resource.variantQuality?.let { quality ->
                if (route.lastRequestedVariant.getAndSet(quality) != quality) {
                    Log.d("CastLite-HLS", "Receiver requested video variant: $quality")
                }
            }
        }
        // Mantém playlists e segmentos HLS no contexto do navegador de origem.
        if (hlsSource) {
            val range = if (playlistResource) null else receiverHeaders["range"]
            val browserResponse = frameTransport?.fetch(route.pageUrl, resource.url, range)
            if (browserResponse != null) {
                responseStarted = true
                writeFrameResponse(route, resource, browserResponse, method, output,
                    (System.nanoTime() - requestStartedNanos) / 1_000_000L)
                return
            }
        }
        val uri = try { URI(resource.url) } catch (_: Exception) { null }
        if (uri == null || !uri.scheme.equals("http", true) && !uri.scheme.equals("https", true) || uri.host.isNullOrBlank()) {
            writeResponse(output, 400, "Bad Request", emptyMap(), "Invalid media URL".toByteArray(), method == "HEAD")
            return
        }
        val connection = (URL(resource.url).openConnection() as? HttpURLConnection)
            ?: run {
                writeResponse(output, 502, "Bad Gateway", emptyMap(), "Unsupported media transport".toByteArray(), method == "HEAD")
                return
            }
        try {
            connection.instanceFollowRedirects = true
            connection.connectTimeout = 20_000
            connection.readTimeout = 60_000
            connection.requestMethod = method
            connection.setRequestProperty("User-Agent", route.userAgent)
            connection.setRequestProperty("Accept-Encoding", "identity")
            listOf("Accept", "Accept-Language", "Origin", "Authorization").forEach { name ->
                route.requestHeaders.entries.firstOrNull { it.key.equals(name, ignoreCase = true) }
                    ?.value?.safeHeaderValue()?.let { connection.setRequestProperty(name, it) }
            }
            val referer = route.requestHeaders.entries.firstOrNull { it.key.equals("Referer", ignoreCase = true) }
                ?.value?.takeIf { it.isNotBlank() } ?: route.pageUrl
            referer.safeHeaderValue()?.takeIf { it.startsWith("http://") || it.startsWith("https://") }
                ?.let { connection.setRequestProperty("Referer", it) }
            receiverHeaders["range"]?.safeHeaderValue()?.let { connection.setRequestProperty("Range", it) }
            receiverHeaders["if-range"]?.safeHeaderValue()?.let { connection.setRequestProperty("If-Range", it) }
            val cookies = route.requestHeaders.entries.firstOrNull { it.key.equals("Cookie", ignoreCase = true) }
                ?.value?.safeHeaderValue()
                ?: try { CookieManager.getInstance().getCookie(resource.url) } catch (_: Exception) { null }
            cookies?.takeIf { it.isNotBlank() }?.let { connection.setRequestProperty("Cookie", it) }
            Log.d("CastLite-Relay", "Context headers=${route.requestHeaders.keys.sorted()} cookies=${!cookies.isNullOrBlank()} refererSameHost=${runCatching { URI(referer).host == uri.host }.getOrDefault(false)}")

            val code = connection.responseCode
            val statusText = connection.responseMessage?.takeIf { it.isNotBlank() } ?: reasonPhrase(code)
            val sourceStream = if (code >= 400) connection.errorStream else connection.inputStream
            val contentType = connection.contentType ?: resource.mimeType
            val playlist = HlsPlaylist.isPlaylist(resource.url, contentType, resource.mimeType)
            val isHls = code == HttpURLConnection.HTTP_OK && method == "GET" && playlist
            Log.d("CastLite-Relay", "$method status=$code type=$contentType playlist=$playlist host=${uri.host}")
            if (code == 403 && sourceStream != null) {
                val errorBody = sourceStream.use { readBounded(it, 65_536) }
                val errorText = errorBody?.toString(StandardCharsets.UTF_8).orEmpty()
                Log.w("CastLite-Relay", "Forbidden challenge=${errorText.contains("cf-chl") || errorText.contains("Just a moment")} server=${connection.getHeaderField("Server")}")
                responseStarted = true
                writeResponse(output, code, statusText, mapOf("Content-Type" to "text/plain"),
                    "Origin refused media request".toByteArray(), method == "HEAD")
                return
            }
            if (isHls && sourceStream != null) {
                val manifest = readBounded(sourceStream, MAX_MANIFEST_BYTES)
                if (manifest == null) {
                    writeResponse(output, 502, "Bad Gateway", emptyMap(), "Manifest too large".toByteArray(), false)
                    return
                }
                val text = String(manifest, StandardCharsets.UTF_8)
                Log.d("CastLite-HLS", "Original manifest size=${text.length} bytes")
                val rewrittenText = rewriteHls(text, connection.url.toString(), route)
                android.util.Log.d("CastLite-HLS", "Rewritten manifest size=${rewrittenText.length} bytes")
                val rewritten = rewrittenText.toByteArray(StandardCharsets.UTF_8)
                val forwarded = mapOf("Content-Type" to HlsPlaylist.MIME,
                    "Content-Length" to rewritten.size.toString(), "Cache-Control" to "no-store")
                responseStarted = true
                writeResponse(output, code, statusText, forwarded, rewritten, false)
            } else {
                val contentLength = connection.getHeaderFieldLong("Content-Length", -1L)
                val forwarded = responseHeaders(
                    connection,
                    if (playlist && code == 200) HlsPlaylist.MIME else contentType,
                    contentLength,
                    resource.mimeType
                )
                responseStarted = true
                writeResponse(output, code, statusText, forwarded, sourceStream, method == "HEAD")
                if (hlsSource && !playlistResource && code in 200..299) {
                    Log.d("CastLite-Relay", "HLS segment transport=direct status=$code bytes=$contentLength elapsedMs=${(System.nanoTime() - requestStartedNanos) / 1_000_000L}")
                }
            }
        } catch (error: Exception) {
            if (responseStarted) {
                Log.w("CastLite-Relay", "Media response interrupted: ${error.javaClass.simpleName}")
                return
            }
            Log.w("CastLite-Relay", "Origin request failed: ${error.javaClass.simpleName}")
            writeResponse(output, 502, "Bad Gateway", emptyMap(), "Unable to fetch origin media".toByteArray(), method == "HEAD")
        } finally {
            connection.disconnect()
        }
    }

    private fun writeFrameResponse(
        route: Route,
        resource: Resource,
        response: FrameMediaTransport.Response,
        method: String,
        output: BufferedOutputStream,
        elapsedMs: Long
    ) {
        val playlist = HlsPlaylist.isPlaylist(resource.url, response.type, resource.mimeType)
        val mediaType = MediaPayload.contentType(response.body, response.type)
        Log.d("CastLite-Relay", "Browser $method status=${response.status} type=$mediaType playlist=$playlist bytes=${response.body.size} elapsedMs=$elapsedMs")
        val body = if (response.status == 200 && playlist) {
            runCatching { rewriteHls(response.body.toString(StandardCharsets.UTF_8), response.finalUrl, route)
                .toByteArray(StandardCharsets.UTF_8) }.getOrNull()
        } else response.body
        if (body == null) {
            writeResponse(output, 502, "Bad Gateway", emptyMap(), "Invalid HLS playlist".toByteArray(), false)
            return
        }
        val headers = mutableMapOf(
            "Content-Type" to if (playlist && response.status == 200) HlsPlaylist.MIME else response.type,
            "Cache-Control" to "no-store",
            "Content-Length" to body.size.toString()
        )
        if (!playlist) headers["Content-Type"] = mediaType
        if (response.contentRange.isNotBlank()) headers["Content-Range"] = response.contentRange
        writeResponse(output, response.status, reasonPhrase(response.status), headers, body, method == "HEAD")
    }

    private fun responseHeaders(
        connection: HttpURLConnection,
        contentType: String?,
        contentLength: Long,
        fallbackMimeType: String? = null
    ): Map<String, String> {
        val forwarded = linkedMapOf<String, String>()
        val actualType = contentType?.takeIf { it.isNotBlank() && !it.equals("application/octet-stream", true) }
            ?: fallbackMimeType?.takeIf { it.isNotBlank() }
            ?: contentType?.takeIf { it.isNotBlank() }
        if (actualType != null) forwarded["Content-Type"] = actualType
        else forwarded["Content-Type"] = "application/octet-stream"
        listOf("Content-Range", "Accept-Ranges", "ETag", "Last-Modified", "Cache-Control", "Expires").forEach { name ->
            connection.getHeaderField(name)?.let { forwarded[name] = it }
        }
        if (contentLength >= 0) forwarded["Content-Length"] = contentLength.toString()
        return forwarded
    }

    private fun writeResponse(
        output: BufferedOutputStream,
        code: Int,
        reason: String,
        headers: Map<String, String>,
        body: Any?,
        headOnly: Boolean
    ) {
        output.write("HTTP/1.1 $code $reason\r\n".toByteArray(StandardCharsets.ISO_8859_1))
        val hasLength = headers.keys.any { it.equals("Content-Length", true) }
        headers.forEach { (name, value) ->
            if (name.safeHeaderValue() != null && value.safeHeaderValue() != null) {
                output.write("$name: $value\r\n".toByteArray(StandardCharsets.ISO_8859_1))
            }
        }
        if (!hasLength && body is ByteArray) output.write("Content-Length: ${body.size}\r\n".toByteArray(StandardCharsets.ISO_8859_1))
        output.write("Access-Control-Allow-Origin: *\r\n".toByteArray(StandardCharsets.ISO_8859_1))
        output.write("Access-Control-Allow-Headers: Range, Origin, Accept, Content-Type, If-Range\r\n".toByteArray(StandardCharsets.ISO_8859_1))
        output.write("Access-Control-Expose-Headers: Content-Length, Content-Range, Accept-Ranges, Content-Type\r\n".toByteArray(StandardCharsets.ISO_8859_1))
        output.write("Connection: close\r\n\r\n".toByteArray(StandardCharsets.ISO_8859_1))
        if (!headOnly && body != null) {
            when (body) {
                is ByteArray -> output.write(body)
                is InputStream -> body.use { stream ->
                    val buffer = ByteArray(32 * 1024)
                    while (true) {
                        val read = stream.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                    }
                }
            }
        }
        output.flush()
    }

    private fun rewriteHls(manifest: String, baseUrl: String, route: Route): String {
        HlsPlaylist.qualitySummary(manifest)?.let { summary ->
            Log.d("CastLite-HLS", "Quality variants: $summary")
        }
        return HlsPlaylist.rewrite(if (route.economy) HlsPlaylist.economical(manifest) else manifest, baseUrl) { target, mimeType, variantQuality ->
            val resourceId = UUID.randomUUID().toString().replace("-", "")
            route.resources[resourceId] = Resource(target, mimeType, variantQuality)
            "http://${route.host}:${route.port}/${route.token}/$resourceId"
        }
    }

    private fun readBounded(input: InputStream, limit: Int): ByteArray? {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            if (out.size() + count > limit) return null
            out.write(buffer, 0, count)
        }
        return out.toByteArray()
    }

    private fun findPrivateIpv4(): String? {
        return try {
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return null
            Collections.list(interfaces)
                .filter { it.isUp && !it.isLoopback && (it.name.startsWith("wlan") || it.name.startsWith("wifi") || it.name == "eth0") }
                .asSequence()
                .flatMap { Collections.list(it.inetAddresses).asSequence() }
                .filterIsInstance<Inet4Address>()
                .firstOrNull { address ->
                    val b = address.address.map { it.toInt() and 0xff }
                    !address.isLoopbackAddress && !address.isLinkLocalAddress &&
                        (b[0] == 10 || (b[0] == 172 && b[1] in 16..31) || (b[0] == 192 && b[1] == 168) || (b[0] == 100 && b[1] in 64..127))
                }?.hostAddress
        } catch (_: Exception) { null }
    }

    private fun String?.safeHeaderValue(): String? = this?.takeIf { it.length <= 8192 && '\r' !in it && '\n' !in it }

    private fun reasonPhrase(code: Int): String = when (code) {
        200 -> "OK"; 206 -> "Partial Content"; 301 -> "Moved Permanently"; 302 -> "Found"; 304 -> "Not Modified"
        400 -> "Bad Request"; 403 -> "Forbidden"; 404 -> "Not Found"; 416 -> "Range Not Satisfiable"
        500 -> "Internal Server Error"; 502 -> "Bad Gateway"; 503 -> "Service Unavailable"; else -> "Response"
    }

    override fun close() {
        synchronized(serverLock) {
            try { server?.close() } catch (_: Exception) { }
            server = null
            workers?.shutdownNow()
            workers = null
            routes.clear()
        }
    }

    private companion object {
        const val MAX_MANIFEST_BYTES = 4 * 1024 * 1024
    }
}
