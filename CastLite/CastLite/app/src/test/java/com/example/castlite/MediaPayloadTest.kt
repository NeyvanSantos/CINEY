package com.example.castlite

import org.junit.Assert.assertEquals
import org.junit.Test

class MediaPayloadTest {
    @Test fun detectsFragmentedReadsWithoutConsumingMedia() {
        val bytes = ByteArray(1024).apply { this[0] = 0x47; this[188] = 0x47; this[376] = 0x47 }
        val fragmented = object : java.io.ByteArrayInputStream(bytes) {
            override fun read(buffer: ByteArray, offset: Int, length: Int): Int =
                super.read(buffer, offset, minOf(length, 31))
        }
        val input = java.io.BufferedInputStream(fragmented)
        assertEquals("video/mp2t", MediaPayload.contentType(input, "application/javascript"))
        org.junit.Assert.assertArrayEquals(bytes, input.readBytes())
    }

    @Test fun recognizesTransportStreamDespiteJavascriptHeader() {
        val bytes = ByteArray(564).apply { this[0] = 0x47; this[188] = 0x47; this[376] = 0x47 }
        assertEquals("video/mp2t", MediaPayload.contentType(bytes, "application/javascript"))
    }
    @Test fun doesNotTreatArbitraryTextOrKeysAsTransportStreams() {
        assertEquals("application/javascript", MediaPayload.contentType("Ghello".toByteArray(), "application/javascript"))
        assertEquals("application/octet-stream", MediaPayload.contentType(ByteArray(16), ""))
    }
    @Test fun recognizesFragmentedMp4AndWebVtt() {
        assertEquals("video/mp4", MediaPayload.contentType(byteArrayOf(0, 0, 0, 20) + "styp".toByteArray(), "text/plain"))
        assertEquals("text/vtt", MediaPayload.contentType("WEBVTT\n".toByteArray(), "text/plain"))
    }
}
