package com.example.castlite

import java.io.InputStream
import java.io.IOException
import java.nio.charset.StandardCharsets
import java.util.Locale

/** Bounded HTTP header parser. The caller also limits socket reads by deadline. */
internal object ProxyRequestReader {
    data class Request(val method: String, val target: String, val headers: Map<String, String>)
    fun read(input: InputStream, checkDeadline: () -> Unit = {}): Request {
        var total = 0
        fun line(): String {
            val bytes = java.io.ByteArrayOutputStream()
            while (true) {
                checkDeadline()
                val value = input.read()
                if (value < 0) throw IOException("Incomplete HTTP headers")
                if (++total > 32768 || bytes.size() >= 8192) throw IOException("HTTP headers too large")
                if (value == 10) return bytes.toString(StandardCharsets.ISO_8859_1.name()).removeSuffix("\r")
                bytes.write(value)
            }
        }
        val parts = line().split(' ')
        if (parts.size != 3 || !parts[2].startsWith("HTTP/1.") || !parts[1].startsWith('/')) throw IOException("Invalid request")
        val headers = linkedMapOf<String, String>()
        repeat(65) { index ->
            val value = line()
            if (value.isEmpty()) return Request(parts[0].uppercase(Locale.ROOT), parts[1], headers)
            if (index == 64) throw IOException("Too many headers")
            val colon = value.indexOf(':')
            if (colon <= 0) throw IOException("Invalid header")
            headers[value.substring(0, colon).trim().lowercase(Locale.ROOT)] = value.substring(colon + 1).trim()
        }
        throw IOException("Incomplete headers")
    }
}
