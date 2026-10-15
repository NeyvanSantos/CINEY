package com.example.castlite

import com.example.castlite.casting.dlna.DidlLiteBuilder
import com.example.castlite.casting.dlna.DlnaCastTarget
import com.example.castlite.casting.roku.RokuCastTarget
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CastTargetTest {

    // ── DIDL-Lite Builder ──

    @Test
    fun didlLite_containsTitle() {
        val xml = DidlLiteBuilder.buildVideoItem("Test Video", "http://example.com/test.mp4", "video/mp4")
        assertTrue("DIDL must contain escaped title", xml.contains("<dc:title>Test Video</dc:title>"))
    }

    @Test
    fun didlLite_escapesSpecialCharacters() {
        val xml = DidlLiteBuilder.buildVideoItem("A & B <C>", "http://example.com/test.mp4", "video/mp4")
        assertTrue("Ampersand must be escaped", xml.contains("A &amp; B &lt;C&gt;"))
    }

    @Test
    fun didlLite_containsProtocolInfo() {
        val xml = DidlLiteBuilder.buildVideoItem("Test", "http://example.com/test.mp4", "video/mp4")
        assertTrue("Protocol info must include MIME", xml.contains("http-get:*:video/mp4:*"))
    }

    @Test
    fun didlLite_containsMediaUrl() {
        val url = "http://192.168.1.5:12345/abc/source"
        val xml = DidlLiteBuilder.buildVideoItem("Test", url, "video/mp4")
        assertTrue("URL must be present in res element", xml.contains(url))
    }

    // ── DLNA Time Formatting ──

    @Test
    fun dlna_formatTime_zero() {
        assertEquals("00:00:00", DlnaCastTarget.formatTime(0L))
    }

    @Test
    fun dlna_formatTime_oneHour() {
        assertEquals("01:00:00", DlnaCastTarget.formatTime(3600_000L))
    }

    @Test
    fun dlna_formatTime_mixed() {
        // 1h 23m 45s = 5025000 ms
        assertEquals("01:23:45", DlnaCastTarget.formatTime(5_025_000L))
    }

    @Test
    fun dlna_formatTime_negative() {
        assertEquals("00:00:00", DlnaCastTarget.formatTime(-500L))
    }

    // ── DLNA Time Parsing ──

    @Test
    fun dlna_parseTime_hhmmss() {
        assertEquals(3661_000L, DlnaCastTarget.parseTime("01:01:01"))
    }

    @Test
    fun dlna_parseTime_mmss() {
        assertEquals(125_000L, DlnaCastTarget.parseTime("02:05"))
    }

    @Test
    fun dlna_parseTime_withFractions() {
        assertEquals(90_000L, DlnaCastTarget.parseTime("00:01:30.500"))
    }

    @Test
    fun dlna_parseTime_null() {
        assertEquals(0L, DlnaCastTarget.parseTime(null))
    }

    @Test
    fun dlna_parseTime_notImplemented() {
        assertEquals(0L, DlnaCastTarget.parseTime("NOT_IMPLEMENTED"))
    }

    @Test
    fun dlna_parseTime_empty() {
        assertEquals(0L, DlnaCastTarget.parseTime(""))
    }

    // ── Roku helpers ──

    @Test
    fun roku_mediaType_mp4() {
        assertEquals("movie", RokuCastTarget.rokuMediaType("video/mp4"))
    }

    @Test
    fun roku_mediaType_hls() {
        assertEquals("movie", RokuCastTarget.rokuMediaType("application/x-mpegURL"))
    }

    @Test
    fun roku_parseTime_milliseconds() {
        assertEquals(12345L, RokuCastTarget.parseRokuTime("12345"))
    }

    @Test
    fun roku_parseTime_withSuffix() {
        assertEquals(5000L, RokuCastTarget.parseRokuTime("5000 ms"))
    }

    @Test
    fun roku_parseTime_empty() {
        assertEquals(0L, RokuCastTarget.parseRokuTime(""))
    }
}
