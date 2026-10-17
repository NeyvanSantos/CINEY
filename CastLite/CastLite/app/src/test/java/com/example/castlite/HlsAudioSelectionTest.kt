package com.example.castlite

import org.junit.Assert.*
import org.junit.Test

class HlsAudioSelectionTest {
    private val master = """
        #EXTM3U
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",NAME="Original",LANGUAGE="en",DEFAULT=YES,URI="en-aac.m3u8"
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",NAME="Português",LANGUAGE="pt-BR",DEFAULT=NO,URI="pt-aac.m3u8"
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="ac3",NAME="Original",LANGUAGE="en",DEFAULT=YES,URI="en-ac3.m3u8"
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="ac3",NAME="Português",LANGUAGE="por",DEFAULT=NO,URI="pt-ac3.m3u8"
        #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",URI="subs.m3u8"
        #EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,AUDIO="aac"
        full-hd.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=18000000,RESOLUTION=3840x2160,AUDIO="ac3"
        uhd.m3u8
    """.trimIndent()

    @Test fun selectsPortugueseWithinEveryAudioGroupAndKeepsFullQuality() {
        val result = HlsPlaylist.rewrite(master, "https://example.com/master.m3u8", "pt") { url, _, _ -> url }
        assertFalse(result.contains("en-aac.m3u8"))
        assertFalse(result.contains("en-ac3.m3u8"))
        assertTrue(result.contains("pt-aac.m3u8"))
        assertTrue(result.contains("pt-ac3.m3u8"))
        assertEquals(2, result.lines().count { it.contains("TYPE=AUDIO") && it.contains("DEFAULT=YES") })
        assertTrue(result.contains("TYPE=SUBTITLES"))
        assertTrue(result.contains("RESOLUTION=1920x1080"))
        assertTrue(result.contains("RESOLUTION=3840x2160"))
        assertTrue(result.contains("BANDWIDTH=18000000"))
    }

    @Test fun unspecifiedLanguageKeepsProviderDefaultsAndAllAudioOptions() {
        val result = HlsPlaylist.rewrite(master, "https://example.com/master.m3u8", null) { url, _, _ -> url }
        assertEquals(4, result.lines().count { it.contains("TYPE=AUDIO") })
        assertTrue(result.lines().first { it.contains("en-aac") }.contains("DEFAULT=YES"))
        assertTrue(result.lines().first { it.contains("pt-aac") }.contains("DEFAULT=NO"))
    }

    @Test fun unavailableLanguageDoesNotRemoveWorkingAudio() {
        val result = HlsPlaylist.rewrite(master, "https://example.com/master.m3u8", "fr") { url, _, _ -> url }
        assertEquals(4, result.lines().count { it.contains("TYPE=AUDIO") })
    }
}
