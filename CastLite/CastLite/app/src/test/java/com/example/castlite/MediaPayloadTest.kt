package com.example.castlite

import org.junit.Assert.assertEquals
import org.junit.Test

class MediaPayloadTest {
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
