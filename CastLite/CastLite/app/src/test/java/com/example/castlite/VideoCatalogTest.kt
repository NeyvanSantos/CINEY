package com.example.castlite

import org.junit.Assert.*
import org.junit.Test

class VideoCatalogTest {
    private fun video(url: String) = DetectedVideo(url, "Teste", "https://site.example", "video/mp4")

    @Test fun `deduplica a mesma url detectada na rede e no DOM`() {
        val catalog = VideoCatalog()
        val video = video("https://cdn.example/filme.mp4?sig=Ab%2BC")
        assertTrue(catalog.add(video, catalog.pageId))
        assertFalse(catalog.add(video, catalog.pageId))
        assertEquals(listOf(video), catalog.snapshot())
    }
    @Test fun `enriquece URL deduplicada com cabecalhos da requisicao`() {
        val catalog = VideoCatalog()
        val video = video("https://cdn.example/filme.mp4")
        catalog.add(video, catalog.pageId)
        val enriched = video.copy(requestHeaders = mapOf("Referer" to "https://site.example/watch", "User-Agent" to "WebView"))

        assertFalse(catalog.add(enriched, catalog.pageId))
        assertEquals(enriched.requestHeaders, catalog.snapshot().single().requestHeaders)
        assertEquals(1, catalog.size)
    }
    @Test fun `nova pagina limpa lista e rejeita callback antigo`() {
        val catalog = VideoCatalog()
        val oldPage = catalog.pageId
        catalog.add(video("https://cdn.example/antigo.mp4"), oldPage)
        catalog.beginPage()
        assertEquals(0, catalog.size)
        assertFalse(catalog.add(video("https://cdn.example/atrasado.mp4"), oldPage))
        assertTrue(catalog.add(video("https://cdn.example/novo.mp4"), catalog.pageId))
        assertEquals(1, catalog.size)
    }
    @Test fun `nao funde URLs com assinaturas diferentes`() {
        val catalog = VideoCatalog()
        catalog.add(video("https://cdn.example/v.mp4?sig=A"), catalog.pageId)
        catalog.add(video("https://cdn.example/v.mp4?sig=B"), catalog.pageId)
        assertEquals(2, catalog.size)
    }
}
