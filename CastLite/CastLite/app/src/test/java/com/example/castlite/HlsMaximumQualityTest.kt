package com.example.castlite

import org.junit.Assert.*
import org.junit.Test

class HlsMaximumQualityTest {
    @Test fun keepsHighestResolutionAndPreservesAudioSubtitlesAndKeys() {
        val master = """#EXTM3U
            |#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="pt",URI="audio.m3u8"
            |#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="sub",URI="subs.m3u8"
            |#EXT-X-SESSION-KEY:METHOD=AES-128,URI="key"
            |#EXT-X-STREAM-INF:BANDWIDTH=276000,RESOLUTION=640x360
            |360.m3u8
            |#EXT-X-STREAM-INF:BANDWIDTH=2048000,RESOLUTION=1280x720
            |720.m3u8
        """.trimMargin()
        val result = HlsPlaylist.maximumQuality(master)
        assertFalse(result.contains("360.m3u8"))
        assertTrue(result.contains("720.m3u8"))
        assertTrue(result.contains("audio.m3u8"))
        assertTrue(result.contains("subs.m3u8"))
        assertTrue(result.contains("URI=\"key\""))
    }

    @Test fun prefersResolutionOverBandwidthAndKeepsCodecAlternativesAtThatResolution() {
        val master = "#EXTM3U\n" +
            "#EXT-X-STREAM-INF:BANDWIDTH=12000000,RESOLUTION=1920x1080\n1080.m3u8\n" +
            "#EXT-X-STREAM-INF:BANDWIDTH=8000000,RESOLUTION=3840x2160,CODECS=\"hvc1\"\n4k-hevc.m3u8\n" +
            "#EXT-X-STREAM-INF:BANDWIDTH=16000000,RESOLUTION=3840x2160,CODECS=\"avc1\"\n4k-avc.m3u8"
        val result = HlsPlaylist.maximumQuality(master)
        assertFalse(result.contains("1080.m3u8"))
        assertTrue(result.contains("4k-hevc.m3u8"))
        assertTrue(result.contains("4k-avc.m3u8"))
    }

    @Test fun usesHighestBandwidthWhenAllResolutionsAreAbsent() {
        val master = "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=300000\nlow\n" +
            "#EXT-X-STREAM-INF:BANDWIDTH=4000000\nhigh"
        val result = HlsPlaylist.maximumQuality(master)
        assertFalse(result.lines().contains("low"))
        assertTrue(result.lines().contains("high"))
    }

    @Test fun preservesMediaPlaylistsAndIncompleteMetadata() {
        listOf(
            "#EXTM3U\n#EXTINF:10,\nsegment.ts\n#EXT-X-ENDLIST",
            "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=300000\nlow\n#EXT-X-STREAM-INF:CODECS=\"avc1\"\nunknown",
            "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=300000,RESOLUTION=640x360\nlow\n#EXT-X-STREAM-INF:BANDWIDTH=4000000\nunknown",
            "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=300000\nlow\n#EXT-X-STREAM-INF:BANDWIDTH=4000000"
        ).forEach { assertEquals(it, HlsPlaylist.maximumQuality(it)) }
    }

    @Test fun selectedVariantsStillPassThroughRelayRewriting() {
        val master = "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=276000,RESOLUTION=640x360\n360.m3u8\n" +
            "#EXT-X-STREAM-INF:BANDWIDTH=2048000,RESOLUTION=1280x720\n720.m3u8"
        val targets = mutableListOf<String>()
        val result = HlsPlaylist.rewrite(HlsPlaylist.maximumQuality(master), "https://example.test/master.m3u8") { url, _ ->
            targets.add(url)
            "http://relay.test/resource"
        }
        assertEquals(listOf("https://example.test/720.m3u8"), targets)
        assertTrue(result.contains("http://relay.test/resource"))
    }
}
