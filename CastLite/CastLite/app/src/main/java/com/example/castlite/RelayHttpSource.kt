package com.example.castlite

import java.io.Closeable
import java.io.EOFException
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

/** Retries reads without replaying bytes already delivered to the receiver. */
internal class RelayHttpSource(
    private val url: String,
    private val method: String,
    private val headers: Map<String, String>,
    private val retryDelayMs: Long = 250,
    private val headerOrigin: String = url,
    private val cookiesForUrl: (String) -> String? = { null },
) : Closeable {
    var connection: HttpURLConnection = open(headers)
        private set

    private fun open(requestHeaders: Map<String, String>): HttpURLConnection {
        var lastError: IOException? = null
        repeat(3) { attempt ->
            var candidate: HttpURLConnection? = null
            try {
                candidate = openFollowingRedirects(requestHeaders)
                val code = candidate.responseCode
                if (code !in listOf(408, 429, 500, 502, 503, 504) || attempt == 2) return candidate
                candidate.disconnect()
            } catch (error: IOException) {
                candidate?.disconnect()
                lastError = error
                if (attempt == 2) throw error
            }
            if (retryDelayMs > 0) Thread.sleep(retryDelayMs * (attempt + 1))
        }
        throw lastError ?: IOException("Origin unavailable")
    }

    private fun openFollowingRedirects(requestHeaders: Map<String, String>): HttpURLConnection {
        var destination = URL(url)
        repeat(9) { hop ->
            val candidate = destination.openConnection() as HttpURLConnection
            try {
                candidate.instanceFollowRedirects = false
                candidate.connectTimeout = 8_000
                candidate.readTimeout = 20_000
                candidate.requestMethod = method
                val scoped = RelayHeaderPolicy.forTarget(requestHeaders, headerOrigin, destination.toString())
                scoped.forEach { (name, value) -> candidate.setRequestProperty(name, value) }
                if (scoped.keys.none { it.equals("Cookie", true) }) {
                    cookiesForUrl(destination.toString())?.takeIf { '\r' !in it && '\n' !in it && it.length <= 8192 }
                        ?.let { candidate.setRequestProperty("Cookie", it) }
                }
                val code = candidate.responseCode
                if (code !in listOf(301, 302, 303, 307, 308)) return candidate
                val location = candidate.getHeaderField("Location") ?: return candidate
                val next = URL(destination, location)
                if (hop == 8 || next.protocol !in listOf("http", "https") || next.userInfo != null ||
                    destination.protocol == "https" && next.protocol != "https") throw IOException("Unsafe media redirect")
                candidate.disconnect()
                destination = next
            } catch (error: Exception) {
                candidate.disconnect()
                throw error
            }
        }
        throw IOException("Too many media redirects")
    }

    fun stream(): InputStream {
        val initial = connection
        if (method != "GET" || initial.responseCode !in listOf(200, 206)) return initial.inputStream
        val length = initial.getHeaderFieldLong("Content-Length", -1)
        val initialRange = if (initial.responseCode == 206) contentRange(initial.getHeaderField("Content-Range")) else null
        if (initial.responseCode == 206 && (initialRange == null ||
                length >= 0 && initialRange.end - initialRange.start + 1 != length)) {
            throw IOException("Invalid initial media range")
        }
        val requested = headers.entries.lastOrNull { it.key.equals("Range", true) }?.value
        if (initialRange != null && requested != null) {
            val range = Regex("bytes=(\\d*)-(\\d*)", RegexOption.IGNORE_CASE).matchEntire(requested.trim())
                ?: throw IOException("Unsupported receiver range")
            val first = range.groupValues[1]
            val last = range.groupValues[2]
            if (first.isNotEmpty()) {
                val expectedStart = first.toLongOrNull() ?: throw IOException("Invalid receiver range")
                val expectedEnd = last.takeIf { it.isNotEmpty() }?.toLongOrNull()
                if (initialRange.start != expectedStart ||
                    last.isNotEmpty() && (expectedEnd == null || initialRange.end > expectedEnd)) {
                    throw IOException("Origin returned a different receiver range")
                }
            } else {
                val suffix = last.toLongOrNull()?.takeIf { it > 0 } ?: throw IOException("Invalid receiver range")
                initialRange.total?.let { total ->
                    if (initialRange.end != total - 1 || initialRange.start != (total - suffix).coerceAtLeast(0)) {
                        throw IOException("Origin returned a different suffix range")
                    }
                }
            }
        }
        val start = initialRange?.start ?: 0L
        val total = initialRange?.total ?: length.takeIf { initial.responseCode == 200 && it >= 0 }
        val strongEtag = initial.getHeaderField("ETag")?.takeUnless { it.startsWith("W/") }
        val validatorHeader = if (strongEtag != null) "ETag" else "Last-Modified"
        val validator = strongEtag ?: initial.getHeaderField(validatorHeader)
        return object : InputStream() {
            private var input = initial.inputStream
            private var delivered = 0L
            private var reconnects = 0

            override fun read(): Int {
                val single = ByteArray(1)
                return if (read(single, 0, 1) < 0) -1 else single[0].toInt() and 0xff
            }

            override fun read(bytes: ByteArray, offset: Int, count: Int): Int {
                if (count == 0) return 0
                while (true) {
                    try {
                        if (length >= 0 && delivered == length) return -1
                        val remaining = if (length >= 0) minOf(count.toLong(), length - delivered).toInt() else count
                        val read = input.read(bytes, offset, remaining)
                        if (read < 0 && length >= 0 && delivered < length) throw EOFException("Truncated media response")
                        if (read > 0) delivered += read
                        return read
                    } catch (error: IOException) {
                        // Unknown/chunked lengths cannot be resumed safely. A
                        // server must confirm the exact byte offset with 206.
                        if (length < 0 || delivered >= length || reconnects++ >= 2) throw error
                        runCatching { input.close() }
                        connection.disconnect()
                        val nextOffset = start + delivered
                        val retryHeaders = headers.filterKeys { !it.equals("Range", true) && !it.equals("If-Range", true) }.toMutableMap()
                        retryHeaders["Range"] = "bytes=$nextOffset-${start + length - 1}"
                        if (validator != null) retryHeaders["If-Range"] = validator
                        val next = open(retryHeaders)
                        connection = next
                        val nextRange = contentRange(next.getHeaderField("Content-Range"))
                        val nextLength = next.getHeaderFieldLong("Content-Length", -1)
                        if (next.responseCode != 206 || nextRange == null || nextRange.start != nextOffset ||
                            nextRange.end != start + length - 1 || (total != null && nextRange.total != total) ||
                            (nextLength >= 0 && nextLength != length - delivered) ||
                            (validator != null && next.getHeaderField(validatorHeader) != validator)) {
                            next.disconnect()
                            throw IOException("Origin did not honor media resume", error)
                        }
                        input = next.inputStream
                    }
                }
            }

            override fun close() = input.close()
        }
    }

    override fun close() = connection.disconnect()

    private data class ContentRange(val start: Long, val end: Long, val total: Long?)

    private fun contentRange(value: String?): ContentRange? {
        val match = value?.let { Regex("bytes (\\d+)-(\\d+)/(\\d+|\\*)").matchEntire(it) } ?: return null
        val start = match.groupValues[1].toLongOrNull() ?: return null
        val end = match.groupValues[2].toLongOrNull() ?: return null
        val total = match.groupValues[3].takeUnless { it == "*" }?.toLongOrNull()
        if (match.groupValues[3] != "*" && total == null) return null
        if (end < start || end == Long.MAX_VALUE || (total != null && end >= total)) return null
        return ContentRange(start, end, total)
    }
}
