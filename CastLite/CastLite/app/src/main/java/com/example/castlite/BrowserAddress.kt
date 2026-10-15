package com.example.castlite

import java.net.URLEncoder

/** Converte texto livre em pesquisa, sem permitir esquemas como javascript: e file:. */
object BrowserAddress {
    fun resolve(text: String): String? {
        val input = text.trim()
        if (input.isEmpty()) return null
        if (VideoDetector.isHttpUrl(input)) return input
        val candidate = "https://$input"
        val looksLikeHost = input.substringBefore('/').let {
            it.contains('.') || it.startsWith("localhost") || it.startsWith('[')
        }
        if (looksLikeHost && VideoDetector.isHttpUrl(candidate)) return candidate
        return "https://www.google.com/search?q=" + URLEncoder.encode(input, "UTF-8")
    }
}
