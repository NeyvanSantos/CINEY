package com.example.castlite

import org.junit.Assert.*
import org.junit.Test

class BrowserAddressTest {
    @Test fun `preserva url assinada sem modificar query`() {
        val url = "https://cdn.example/filme.mp4?sig=Ab%2BC+De&expires=123#t=1"
        assertEquals(url, BrowserAddress.resolve(" $url "))
    }
    @Test fun `completa dominio sem protocolo`() {
        assertEquals("https://example.com/video", BrowserAddress.resolve("example.com/video"))
        assertEquals("https://192.168.1.2:8080/test", BrowserAddress.resolve("192.168.1.2:8080/test"))
    }
    @Test fun `aceita protocolo sem diferenciar maiusculas`() {
        assertEquals("HTTPS://example.com", BrowserAddress.resolve("HTTPS://example.com"))
    }
    @Test fun `pesquisa texto com espaco e acento`() {
        assertEquals("https://www.google.com/search?q=v%C3%ADdeos+da+natureza", BrowserAddress.resolve("vídeos da natureza"))
    }
    @Test fun `entrada vazia nao navega`() { assertNull(BrowserAddress.resolve("  ")) }
    @Test fun `nunca executa javascript digitado`() {
        assertTrue(BrowserAddress.resolve("javascript:alert(1)")!!.startsWith("https://www.google.com/search?q="))
    }
}
