package com.example.castlite

import org.junit.Assert.*
import org.junit.Test

class VideoDetectorTest {
    @Test fun `reconhece hls declarado pelo player sem transformar qualquer txt em video`() {
        val url = "https://player.example/signed/123/master.txt?token=Ab%2BC"
        assertNull(VideoDetector.mimeTypeFor(url))
        assertEquals("application/x-mpegURL", VideoDetector.mimeTypeFor(url, "hls"))
        assertNull(VideoDetector.mimeTypeFor(url, "text/plain"))
    }

    @Test fun `tipo declarado tem prioridade sobre pistas ambiguas da url`() {
        assertEquals("application/x-mpegURL", VideoDetector.mimeTypeFor("https://cdn.example/dash/manifest", "HLS"))
        assertEquals("application/dash+xml", VideoDetector.mimeTypeFor("https://player.example/md/token", "dash"))
    }
    @Test fun `reconhece os quatro formatos com query e fragmento`() {
        mapOf("MP4" to "video/mp4", "M3U8" to "application/x-mpegURL",
            "mpd" to "application/dash+xml", "webm" to "video/webm").forEach { (extension, mime) ->
            assertEquals(mime, VideoDetector.mimeTypeFor("https://cdn.example/filme.$extension?token=Ab%2BC#t=10"))
        }
    }

    @Test fun `ignora blob e esquemas nao transmitiveis mesmo com mime declarado`() {
        listOf("blob:https://site.example/filme.mp4", "file:///filme.mp4", "data:video/mp4,AA",
            "javascript:alert(1)", "httpfake://site.example/a.mp4", "https:///a.mp4",
            "https://user:password@site.example/a.mp4", "").forEach {
            assertNull(it, VideoDetector.mimeTypeFor(it, "video/mp4"))
        }
    }

    @Test fun `nao confunde query dominio ou segmentos com extensao de video`() {
        listOf("https://site.example/embed?url=filme.mp4", "https://filme.mp4",
            "https://site.example/filme.mp4/preview", "https://site.example/a.mp4.html").forEach {
            assertFalse(it, VideoDetector.isVideoUrl(it))
        }
    }

    @Test fun `usa mime conhecido de source sem extensao`() {
        assertEquals("application/x-mpegURL", VideoDetector.mimeTypeFor("https://cdn.example/play?id=2", "application/vnd.apple.mpegurl"))
        assertEquals("video/webm", VideoDetector.mimeTypeFor("https://cdn.example/play", "video/webm; codecs=vp9"))
    }

    @Test fun `nao inventa mp4 para url desconhecida`() {
        assertNull(VideoDetector.mimeTypeFor("https://cdn.example/play"))
        assertNull(VideoDetector.mimeTypeFor("https://cdn.example/play", "text/html"))
    }

    @Test fun `aceita http local e extensao codificada`() {
        assertEquals("video/mp4", VideoDetector.mimeTypeFor("http://192.168.1.2:8080/video%2Emp4"))
    }
}
