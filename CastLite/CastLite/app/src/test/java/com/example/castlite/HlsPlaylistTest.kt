package com.example.castlite

import org.junit.Assert.*
import org.junit.Test

class HlsPlaylistTest {
    @Test fun declaredHlsOverridesPlainTextResponse() {
        assertTrue(HlsPlaylist.isPlaylist("https://example.com/master.txt", "text/plain", HlsPlaylist.MIME))
        assertFalse(HlsPlaylist.isPlaylist("https://example.com/readme.txt", "text/plain", null))
    }

    @Test fun masterPropagatesPlaylistTypeToVideoAudioAndSubtitles() {
        val resources = mutableListOf<Pair<String, String?>>()
        val result = HlsPlaylist.rewrite("""
            #EXTM3U
            #EXT-X-MEDIA:TYPE=AUDIO,URI="/audio/opaque?token=a%2Fb+z"
            #EXT-X-MEDIA:TYPE=SUBTITLES,URI="subtitles"
            #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=100,URI="iframes"
            #EXT-X-STREAM-INF:BANDWIDTH=1000
            #comment
            /m3/signed
        """.trimIndent(), "https://example.com/path/master.txt") { url, mime ->
            resources.add(url to mime)
            "http://phone/${resources.size}"
        }
        assertEquals(4, resources.size)
        assertTrue(resources.all { it.second == HlsPlaylist.MIME })
        assertEquals("https://example.com/audio/opaque?token=a%2Fb+z", resources[0].first)
        assertEquals("https://example.com/path/subtitles", resources[1].first)
        assertTrue(result.endsWith("http://phone/4"))
        assertFalse(result.contains("/m3/signed"))
    }

    @Test fun mediaSegmentsKeysAndMapsAreNotPlaylists() {
        val resources = mutableListOf<Pair<String, String?>>()
        HlsPlaylist.rewrite("""
            #EXTM3U
            #EXT-X-KEY:METHOD=AES-128,URI="key"
            #EXT-X-MAP:URI="init"
            #EXTINF:6,
            /md/segment?signature=a%2Fb
            #EXT-X-PART:DURATION=0.5,URI="part"
            #EXT-X-RENDITION-REPORT:URI="other",LAST-MSN=1
        """.trimIndent(), "https://example.com/m3/opaque") { url, mime ->
            resources.add(url to mime); "http://phone/${resources.size}"
        }
        assertTrue(resources.take(4).all { it.second == null })
        assertEquals(HlsPlaylist.MIME, resources.last().second)
        assertEquals("https://example.com/md/segment?signature=a%2Fb", resources[2].first)
    }

    @Test fun qualitySummaryReportsVariantResolutionAndBitrateWithoutUrls() {
        val summary = HlsPlaylist.qualitySummary("""
            #EXTM3U
            #EXT-X-STREAM-INF:CODECS="avc1.64001f,mp4a.40.2",BANDWIDTH=2800000,RESOLUTION=1280x720,AVERAGE-BANDWIDTH=2500000
            https://cdn.example/720/playlist.m3u8?token=secret
            #EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
            https://cdn.example/1080/playlist.m3u8?signature=secret
        """.trimIndent())

        assertNotNull(summary)
        assertTrue(summary!!.contains("master variants=2"))
        assertTrue(summary.contains("resolution=1280x720 bandwidth=2800kbps avg=2500kbps"))
        assertTrue(summary.contains("resolution=1920x1080 bandwidth=5000kbps"))
        assertFalse(summary.contains("cdn.example"))
        assertFalse(summary.contains("token"))
        assertFalse(summary.contains("signature"))
    }

    @Test fun qualitySummaryReturnsNullForMediaPlaylistWithoutVariants() {
        assertNull(HlsPlaylist.qualitySummary("#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6,"))
        assertNull(HlsPlaylist.qualitySummary("<html>not an HLS manifest</html>"))
    }

    @Test fun qualitySummaryLimitsLoggedVariantDetails() {
        val manifest = buildString {
            appendLine("#EXTM3U")
            repeat(24) { appendLine("#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=640x360") }
        }
        val summary = HlsPlaylist.qualitySummary(manifest)!!

        assertTrue(summary.contains("master variants=24"))
        assertTrue(summary.contains("#20 resolution=640x360"))
        assertTrue(summary.contains("4 variants omitted"))
        assertFalse(summary.contains("#21 resolution="))
    }

    @Test fun rewriteCarriesNumericQualityForRequestedVideoVariantOnly() {
        val requestedQualities = mutableListOf<String?>()
        val result = HlsPlaylist.rewrite("""
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720,AVERAGE-BANDWIDTH=2500000
            #variant metadata continues across comments
            https://cdn.example/720/playlist.m3u8?token=secret
        """.trimIndent(), "https://example.com/master.m3u8") { url, _, quality ->
            requestedQualities += quality
            "http://phone/${requestedQualities.size}"
        }

        assertEquals(listOf("resolution=1280x720 bandwidth=2800kbps avg=2500kbps"), requestedQualities)
        assertFalse(result.contains("cdn.example"))
        assertFalse(result.contains("token"))
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsHtmlErrorsInsteadOfRewritingThemAsMedia() {
        HlsPlaylist.rewrite("<html>Access denied</html>", "https://example.com/master.txt") { url, _ -> url }
    }

    @Test fun leavesNonHttpKeySchemesUntouched() {
        val text = "#EXTM3U\n#EXT-X-KEY:METHOD=SAMPLE-AES,URI=\"skd://license\""
        assertEquals(text, HlsPlaylist.rewrite(text, "https://example.com/master") { _, _ -> error("Not HTTP") })
    }

    @Test fun prefersPortugueseAudioAsDefault() {
        val result = HlsPlaylist.rewrite("""
            #EXTM3U
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="English",LANGUAGE="en",DEFAULT=YES,URI="en.m3u8"
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="Português",LANGUAGE="pt-BR",DEFAULT=NO,URI="pt.m3u8"
            #EXT-X-STREAM-INF:BANDWIDTH=1000,AUDIO="aud"
            video.m3u8
        """.trimIndent(), "https://example.com/master.m3u8", "pt") { url, _, _ -> url }
        val lines = result.lines()
        assertFalse(result.contains("NAME=\"English\""))
        assertFalse(result.contains("NAME=\"Original\""))
        assertTrue(lines[1].contains("DEFAULT=YES"))
    }

    @Test fun recognizesAudioTypeWhenAttributeOrderDiffers() {
        val result = HlsPlaylist.rewrite("""
            #EXTM3U
            #EXT-X-MEDIA:GROUP-ID="aud", TYPE = AUDIO, NAME="Original",LANGUAGE="en",DEFAULT=YES,URI="en.m3u8"
            #EXT-X-MEDIA:GROUP-ID="aud", TYPE = AUDIO, NAME="Dublado",DEFAULT=NO,URI="pt.m3u8"
            #EXT-X-STREAM-INF:BANDWIDTH=1000,AUDIO="aud"
            video.m3u8
        """.trimIndent(), "https://example.com/master.m3u8", "pt") { url, _, _ -> url }
        val lines = result.lines()
        assertFalse(result.contains("NAME=\"English\""))
        assertFalse(result.contains("NAME=\"Original\""))
        assertTrue(lines[1].contains("DEFAULT=YES"))
    }

    @Test fun prefersDubbedAudioByNameWhenLanguageIsMissing() {
        val result = HlsPlaylist.rewrite("""
            #EXTM3U
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="Original",DEFAULT=YES,URI="en.m3u8"
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="Dublado",URI="pt.m3u8"
            #EXT-X-STREAM-INF:BANDWIDTH=1000,AUDIO="a"
            video.m3u8
        """.trimIndent(), "https://example.com/master.m3u8", "pt") { url, _, _ -> url }
        val lines = result.lines()
        assertFalse(result.contains("NAME=\"English\""))
        assertFalse(result.contains("NAME=\"Original\""))
        assertTrue(lines[1].contains("DEFAULT=YES"))
    }

    @Test fun keepsSingleAudioTrackUntouched() {
        val text = """
            #EXTM3U
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="English",LANGUAGE="en",DEFAULT=YES,URI="en.m3u8"
            #EXT-X-STREAM-INF:BANDWIDTH=1000,AUDIO="a"
            video.m3u8
        """.trimIndent()
        val result = HlsPlaylist.rewrite(text, "https://example.com/master.m3u8") { url, _ -> url }
        assertTrue(result.lines()[1].contains("DEFAULT=YES"))
    }

    @Test fun keepsDefaultsWhenNoPortugueseAudioExists() {
        val result = HlsPlaylist.rewrite("""
            #EXTM3U
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="English",LANGUAGE="en",DEFAULT=YES,URI="en.m3u8"
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="Español",LANGUAGE="es",DEFAULT=NO,URI="es.m3u8"
            #EXT-X-STREAM-INF:BANDWIDTH=1000,AUDIO="a"
            video.m3u8
        """.trimIndent(), "https://example.com/master.m3u8") { url, _ -> url }
        val lines = result.lines()
        assertTrue(lines[1].contains("DEFAULT=YES"))
        assertTrue(lines[2].contains("DEFAULT=NO"))
    }
}
