package com.example.castlite

/** Alguns CDNs rotulam segmentos TS como JavaScript; usa apenas assinaturas conhecidas. */
internal object MediaPayload {
    fun contentType(input: java.io.BufferedInputStream, original: String): String {
        input.mark(512)
        val prefix = ByteArray(512)
        var size = 0
        try {
            while (size < prefix.size) {
                val count = input.read(prefix, size, prefix.size - size)
                if (count <= 0) break
                size += count
            }
        } finally {
            input.reset()
        }
        return contentType(prefix.copyOf(size), original)
    }

    fun contentType(bytes: ByteArray, original: String): String {
        if (bytes.size > 376 && listOf(0, 188, 376).all { bytes[it] == 0x47.toByte() }) return "video/mp2t"
        if (bytes.size >= 8 && String(bytes, 4, 4, Charsets.US_ASCII) in listOf("ftyp", "styp", "moof")) return "video/mp4"
        if (bytes.size >= 7 && String(bytes, 0, 6, Charsets.US_ASCII) == "WEBVTT") return "text/vtt"
        return original.ifBlank { "application/octet-stream" }
    }
}
