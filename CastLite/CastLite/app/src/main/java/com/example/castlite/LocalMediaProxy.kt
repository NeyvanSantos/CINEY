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
import java.net.URI
import java.nio.charset.StandardCharsets
import java.util.Collections
import java.util.Locale
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread

/**
 * A short-lived LAN HTTP relay so a Cast receiver can fetch media using the
 * browser's cookies/referer/user-agent. Range requests are forwarded unchanged.
 * The random route token is generated per load and is never persisted.
 */
class LocalMediaProxy(context: Context) : Closeable {
    internal var frameTransport: FrameMediaTransport? = null
    @Volatile internal var onAccessDenied: (() -> Unit)? = null
    @Volatile internal var onQualityRequested: ((String) -> Unit)? = null
    @Volatile private var activeToken: String? = null
    private data class Resource(val url: String, val mimeType: String? = null, val variantQuality: String? = null)
    private data class Route(
        val token: String,
        val host: String,
        val port: Int,
        val pageUrl: String,
        val requestHeaders: Map<String, String>,
        val userAgent: String,
        val audioLanguage: String?,
        val denied: (() -> Unit)?,
        val qualityRequested: ((String) -> Unit)?,
        val browserHosts: MutableSet<String> = ConcurrentHashMap.newKeySet(),
        val resources: ConcurrentHashMap<String, Resource> = ConcurrentHashMap(),
        val resourceIds: ConcurrentHashMap<Resource, String> = ConcurrentHashMap(),
        val lastRequestedVariant: AtomicReference<String?> = AtomicReference(null)
    )

    private val appContext = context.applicationContext
    private val routes = ConcurrentHashMap<String, Route>()
    private val serverLock = Any()
    @Volatile private var server: ServerSocket? = null
    @Volatile private var workers: ExecutorService? = null
    private val clients = ConcurrentHashMap.newKeySet<java.net.Socket>()

    /** Returns null when the phone is not on a private IPv4 LAN or the listener cannot start. */
    fun createMediaUrl(video: DetectedVideo, fallbackUserAgent: String): String? {
        val lanAddress = findPrivateIpv4() ?: return null
        return try {
            val listening = ensureServer(lanAddress)
            val token = UUID.randomUUID().toString().replace("-", "")
            val route = Route(
                token = token,
                audioLanguage = video.audioLanguage,
                denied = onAccessDenied,
                qualityRequested = onQualityRequested,
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
            activeToken = token
            "http://${route.host}:${route.port}/$token/source"
        } catch (_: Exception) {
            null
        }
    }

    private fun ensureServer(lanAddress: String): ServerSocket = synchronized(serverLock) {
        server?.takeIf { !it.isClosed && it.inetAddress.hostAddress == lanAddress }?.let { return it }
        if (server != null) close()
        val listening = ServerSocket().apply {
            reuseAddress = true
            bind(InetSocketAddress(lanAddress, 0), 24)
        }
        server = listening
        workers = ThreadPoolExecutor(8, 8, 0L, TimeUnit.MILLISECONDS, ArrayBlockingQueue(16), { runnable ->
            Thread(runnable, "CastLite-media-proxy-worker").apply { isDaemon = true }
        }, ThreadPoolExecutor.AbortPolicy())
        thread(name = "CastLite-media-proxy", isDaemon = true) {
            while (!listening.isClosed) {
                try {
                    val client = listening.accept()
                    val acceptedAt = System.nanoTime()
                    clients.add(client)
                    try {
                        workers?.execute {
                            try { handle(client, acceptedAt) } finally { clients.remove(client) }
                        } ?: run { clients.remove(client); client.close() }
                    } catch (_: RejectedExecutionException) {
                        clients.remove(client)
                        client.close()
                    }
                } catch (_: Exception) {
                    if (!listening.isClosed) Thread.sleep(100)
                }
            }
        }
        listening
    }

    private fun handle(client: java.net.Socket, acceptedAt: Long) {
        client.use { socket ->
            try {
                val input = BufferedInputStream(socket.getInputStream())
                val output = BufferedOutputStream(socket.getOutputStream())
                val request = ProxyRequestReader.read(input) {
                    val remaining = 5000 - (System.nanoTime() - acceptedAt) / 1_000_000
                    if (remaining <= 0) throw java.net.SocketTimeoutException("HTTP header deadline")
                    socket.soTimeout = remaining.toInt().coerceAtLeast(1)
                }
                val method = request.method
                val requestTarget = request.target
                val headers = request.headers
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
                    if (route.token == activeToken) route.qualityRequested?.invoke(quality)
                }
            }
        }
        // Use the streaming HTTP path first. Browser transport buffers whole
        // segments and is only required for origins that reject native requests.
        val resourceHost = runCatching { URI(resource.url).host }.getOrNull()
        if (hlsSource && resourceHost in route.browserHosts) {
            val range = if (playlistResource) null else receiverHeaders["range"]
            val browserResponse = frameTransport?.fetch(route.pageUrl, resource.url, range)
            if (browserResponse != null && browserResponse.status in 200..299) {
                responseStarted = true
                writeFrameResponse(route, resource, browserResponse, method, output,
                    (System.nanoTime() - requestStartedNanos) / 1_000_000L)
                return
            }
            browserResponse?.body?.close()
        }
        val uri = try { URI(resource.url) } catch (_: Exception) { null }
        if (uri == null || !uri.scheme.equals("http", true) && !uri.scheme.equals("https", true) || uri.host.isNullOrBlank() || uri.userInfo != null) {
            writeResponse(output, 400, "Bad Request", emptyMap(), "Invalid media URL".toByteArray(), method == "HEAD")
            return
        }
        val requestHeaders = linkedMapOf("User-Agent" to route.userAgent, "Accept-Encoding" to "identity")
        val scopedHeaders = RelayHeaderPolicy.forTarget(route.requestHeaders, route.resources["source"]!!.url, resource.url)
        listOf("Accept", "Accept-Language", "Origin", "Authorization").forEach { name ->
            scopedHeaders.entries.lastOrNull { it.key.equals(name, true) }
                ?.value?.safeHeaderValue()?.let { requestHeaders[name] = it }
        }
        val referer = route.requestHeaders.entries.firstOrNull { it.key.equals("Referer", true) }
            ?.value?.takeIf { it.isNotBlank() } ?: route.pageUrl
        referer.safeHeaderValue()?.takeIf { it.startsWith("http://") || it.startsWith("https://") }
            ?.let { requestHeaders["Referer"] = it }
        if (!playlistResource) {
            receiverHeaders["range"]?.safeHeaderValue()?.let { requestHeaders["Range"] = it }
            receiverHeaders["if-range"]?.safeHeaderValue()?.let { requestHeaders["If-Range"] = it }
        }
        val cookies = scopedHeaders.entries.lastOrNull { it.key.equals("Cookie", true) }
            ?.value?.safeHeaderValue()
        cookies?.takeIf { it.isNotBlank() }?.let { requestHeaders["Cookie"] = it }
        var source: RelayHttpSource? = null
        try {
            // Inspect a small prefix for HEAD too, so the receiver sees the same
            // media type when probing and downloading a mislabeled HLS segment.
            val inspectHead = method == "HEAD" && hlsSource && !playlistResource
            var opened = openSource(resource.url, if (inspectHead) "GET" else method, requestHeaders)
            source = opened
            if (opened.connection.responseCode == 206 &&
                HlsPlaylist.isPlaylist(resource.url, opened.connection.contentType, resource.mimeType)) {
                opened.close()
                opened = openSource(resource.url, method, requestHeaders.filterKeys {
                    !it.equals("Range", true) && !it.equals("If-Range", true)
                })
                source = opened
                if (opened.connection.responseCode == 206) throw java.io.IOException("Partial HLS manifest")
            }
            val connection = opened.connection
            val code = connection.responseCode
            if (hlsSource && code in listOf(401, 403)) {
                val browserResponse = frameTransport?.fetch(route.pageUrl, resource.url,
                    if (playlistResource) null else receiverHeaders["range"])
                if (browserResponse != null && browserResponse.status in 200..299) {
                    if (resourceHost != null) route.browserHosts.add(resourceHost)
                    responseStarted = true
                    writeFrameResponse(route, resource, browserResponse, method, output,
                        (System.nanoTime() - requestStartedNanos) / 1_000_000L)
                    return
                }
                browserResponse?.body?.close()
            }
            if (code in listOf(401, 403) && route.token == activeToken) route.denied?.invoke()
            val statusText = connection.responseMessage?.takeIf { it.isNotBlank() } ?: reasonPhrase(code)
            val sourceStream = if (code >= 400) connection.errorStream else if (method == "HEAD" && !inspectHead) null else opened.stream()
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
                val mediaStream = sourceStream?.let { BufferedInputStream(it) }
                val mediaType = if (hlsSource && !playlist && code in 200..299 && mediaStream != null) {
                    MediaPayload.contentType(mediaStream, contentType.orEmpty()).also {
                        Log.d("CastLite-Relay", "Media type origin=$contentType forwarded=$it")
                    }
                } else contentType
                val contentLength = connection.getHeaderFieldLong("Content-Length", -1L)
                val forwarded = responseHeaders(
                    connection,
                    if (playlist && code == 200) HlsPlaylist.MIME else mediaType,
                    contentLength,
                    resource.mimeType
                )
                responseStarted = true
                writeResponse(output, code, statusText, forwarded, mediaStream, method == "HEAD")
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
            source?.close()
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
        response.body.use { input ->
            val playlist = HlsPlaylist.isPlaylist(resource.url, response.type, resource.mimeType)
            if (playlist && response.status != 200) throw java.io.IOException("Partial browser HLS manifest")
            val headers = mutableMapOf("Cache-Control" to "no-store")
            if (response.contentRange.isNotBlank()) headers["Content-Range"] = response.contentRange
            if (playlist && response.status == 200) {
                val manifest = readBounded(input, MAX_MANIFEST_BYTES)
                    ?: throw java.io.IOException("Manifest too large")
                val body = rewriteHls(manifest.toString(StandardCharsets.UTF_8), response.finalUrl, route)
                    .toByteArray(StandardCharsets.UTF_8)
                headers["Content-Type"] = HlsPlaylist.MIME
                writeResponse(output, response.status, reasonPhrase(response.status), headers, body, method == "HEAD")
            } else {
                val buffered = BufferedInputStream(input)
                headers["Content-Type"] = MediaPayload.contentType(buffered, response.type)
                Log.d("CastLite-Relay", "Browser stream status=${response.status} startupMs=$elapsedMs")
                writeResponse(output, response.status, reasonPhrase(response.status), headers, buffered, method == "HEAD")
            }
        }
    }

    private fun openSource(url: String, method: String, headers: Map<String, String>) =
        RelayHttpSource(url, method, headers, headerOrigin = url,
            cookiesForUrl = { target -> runCatching { CookieManager.getInstance().getCookie(target) }.getOrNull() })

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
        val selected = HlsPlaylist.maximumQuality(manifest)
        HlsPlaylist.qualitySummary(selected)?.let { summary ->
            Log.d("CastLite-HLS", "Maximum quality selection: $summary")
        }
        return HlsPlaylist.rewrite(selected, baseUrl, route.audioLanguage) { target, mimeType, variantQuality ->
            val resource = Resource(target, mimeType, variantQuality)
            val resourceId = route.resourceIds.computeIfAbsent(resource) {
                UUID.randomUUID().toString().replace("-", "").also { route.resources[it] = resource }
            }
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
            clients.forEach { runCatching { it.close() } }
            clients.clear()
            workers = null
            routes.clear()
            activeToken = null
            onAccessDenied = null
            onQualityRequested = null
        }
    }

    private companion object {
        const val MAX_MANIFEST_BYTES = 4 * 1024 * 1024
    }
}
