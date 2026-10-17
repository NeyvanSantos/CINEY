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
) : Closeable {
    var connection: HttpURLConnection = open(headers)
        private set

    private fun open(requestHeaders: Map<String, String>): HttpURLConnection {
        var lastError: IOException? = null
        repeat(3) { attempt ->
            val candidate = URL(url).openConnection() as HttpURLConnection
            try {
                candidate.instanceFollowRedirects = true
                candidate.connectTimeout = 8_000
                candidate.readTimeout = 20_000
                candidate.requestMethod = method
                requestHeaders.forEach { (name, value) -> candidate.setRequestProperty(name, value) }
                val code = candidate.responseCode
                if (code !in listOf(408, 429, 500, 502, 503, 504) || attempt == 2) return candidate
                candidate.disconnect()
            } catch (error: IOException) {
                candidate.disconnect()
                lastError = error
                if (attempt == 2) throw error
            }
            if (retryDelayMs > 0) Thread.sleep(retryDelayMs * (attempt + 1))
        }
        throw lastError ?: IOException("Origin unavailable")
    }

    fun stream(): InputStream {
        val initial = connection
        if (method != "GET" || initial.responseCode !in listOf(200, 206)) return initial.inputStream
        val length = initial.getHeaderFieldLong("Content-Length", -1)
        val start = if (initial.responseCode == 206)
            rangeStart(initial.getHeaderField("Content-Range")) else 0L
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
                        val read = input.read(bytes, offset, count)
                        if (read < 0 && length >= 0 && delivered < length) throw EOFException("Truncated media response")
                        if (read > 0) delivered += read
                        return read
                    } catch (error: IOException) {
                        // Unknown/chunked lengths cannot be resumed safely. A
                        // server must confirm the exact byte offset with 206.
                        if (start == null || length < 0 || delivered >= length || reconnects++ >= 2) throw error
                        runCatching { input.close() }
                        connection.disconnect()
                        val nextOffset = start + delivered
                        val retryHeaders = headers.filterKeys { !it.equals("Range", true) && !it.equals("If-Range", true) }.toMutableMap()
                        retryHeaders["Range"] = "bytes=$nextOffset-${start + length - 1}"
                        if (validator != null) retryHeaders["If-Range"] = validator
                        val next = open(retryHeaders)
                        connection = next
                        if (next.responseCode != 206 || rangeStart(next.getHeaderField("Content-Range")) != nextOffset ||
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

    private fun rangeStart(value: String?): Long? =
        value?.let { Regex("bytes (\\d+)-\\d+/[\\d*]+").matchEntire(it)?.groupValues?.get(1)?.toLongOrNull() }
}
