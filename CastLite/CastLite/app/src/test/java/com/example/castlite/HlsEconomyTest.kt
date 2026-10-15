package com.example.castlite

import org.junit.Assert.*
import org.junit.Test

class HlsEconomyTest {
    @Test fun keepsAdaptiveLowVariantsAndAudio() {
        val master = """#EXTM3U
            |#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="pt",URI="audio.m3u8"
            |#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,AUDIO="pt"
            |360.m3u8
            |#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720,AUDIO="pt"
            |720.m3u8
            |#EXT-X-STREAM-INF:BANDWIDTH=8000000,RESOLUTION=1920x1080,AUDIO="pt"
            |1080.m3u8
        """.trimMargin()
        val result = HlsPlaylist.economical(master)
        assertTrue(result.contains("audio.m3u8"))
        assertTrue(result.contains("360.m3u8"))
        assertTrue(result.contains("720.m3u8"))
        assertFalse(result.contains("1080.m3u8"))
    }

    @Test fun fallsBackToLowestAvailableInsteadOfEmptyManifest() {
        val result = HlsPlaylist.economical("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=9000000\nhigh\n#EXT-X-STREAM-INF:BANDWIDTH=5000000\nlow")
        assertTrue(result.endsWith("low"))
        assertFalse(result.contains("high"))
    }

    @Test fun leavesMediaPlaylistAndUnknownVariantsUntouched() {
        listOf("#EXTM3U\n#EXTINF:10,\nsegment.ts\n#EXT-X-ENDLIST",
            "#EXTM3U\n#EXT-X-STREAM-INF:CODECS=\"avc1\"\nunknown").forEach {
            assertEquals(it, HlsPlaylist.economical(it))
        }
    }
}
