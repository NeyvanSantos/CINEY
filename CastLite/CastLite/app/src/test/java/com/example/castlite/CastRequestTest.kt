package com.example.castlite

import org.junit.Assert.*
import org.junit.Test

class CastRequestTest {
    private fun payload(): Map<String, Any?> = mapOf(
        "version" to 1, "requestId" to "test_1", "title" to "Episódio 3",
        "posterUrl" to "https://images.example/poster.jpg", "positionMs" to 142000L,
        "sourceIndex" to 0, "contentId" to "series_1", "season" to 2, "episode" to 3,
        "sources" to listOf(mapOf(
            "url" to "https://cdn.example/master?token=Ab%2BC&part=2", "server" to "Dublado",
            "isEmbed" to false, "isDirect" to true, "mimeType" to HlsPlaylist.MIME,
            "headers" to mapOf("Referer" to "https://page.example/"), "audioLanguage" to "pt"
        ))
    )

    @Test fun `preserva dados e URLs assinadas na ida e volta`() {
        val request = CastRequest.fromMap(payload())
        assertEquals(request, CastRequest.fromMap(request.toMap()))
        assertEquals(142000L, request.positionMs)
        assertEquals(3, request.episode)
        assertEquals("pt", request.source.audioLanguage)
        assertEquals("https://cdn.example/master?token=Ab%2BC&part=2", request.source.url)
        assertEquals("https://page.example/", request.source.headers["Referer"])
    }

    @Test fun `embed sempre prevalece sobre flag direto`() {
        val source = CastSource.fromMap(mapOf("url" to "https://page.example/embed?url=a.mp4",
            "isEmbed" to true, "isDirect" to true))
        assertTrue(source.isEmbed)
        assertFalse(source.isDirect)
    }

    @Test fun `rejeita esquemas invalidos e credenciais na URL`() {
        listOf("blob:https://cdn.example/a", "file:///a.mp4", "https://user:pass@cdn.example/a",
            "https:///a.mp4", "javascript:alert(1)").forEach { url ->
            assertThrows(IllegalArgumentException::class.java) { CastSource.fromMap(mapOf("url" to url)) }
        }
    }

    @Test fun `rejeita headers que podem injetar uma segunda linha`() {
        assertThrows(IllegalArgumentException::class.java) {
            CastSource.fromMap(mapOf("url" to "https://cdn.example/a.mp4",
                "headers" to mapOf("Referer" to "https://page.example/\r\nInjected: true")))
        }
    }

    @Test fun `rejeita versao indice e posicao invalidos`() {
        listOf(mapOf("version" to 2), mapOf("sourceIndex" to 3),
            mapOf("positionMs" to -1L), mapOf("sources" to emptyList<Any>())).forEach { change ->
            assertThrows(IllegalArgumentException::class.java) { CastRequest.fromMap(payload() + change) }
        }
    }

    @Test fun `permite trocar servidor mantendo episodio e posicao`() {
        val original = payload()
        val sources = original["sources"] as List<*>
        val request = CastRequest.fromMap(original + ("sources" to (sources + sources)))
        val switched = request.copy(sourceIndex = 1)
        assertEquals(request.episode, switched.episode)
        assertEquals(request.positionMs, switched.positionMs)
        assertEquals(request.source.url, switched.source.url)
    }
}
