package com.example.castlite

/** Mantém a lista por navegação e descarta callbacks pendentes da página anterior. */
class VideoCatalog {
    private val videos = LinkedHashMap<String, DetectedVideo>()
    @Volatile var pageId: Long = 0
        private set

    // Escritas e leitura da lista são feitas na thread da interface.
    fun beginPage() {
        pageId++
        videos.clear()
    }

    fun add(video: DetectedVideo, detectedOnPage: Long): Boolean {
        if (detectedOnPage != pageId) return false
        val existing = videos[video.url]
        if (existing != null) {
            val mergedHeaders = LinkedHashMap(existing.requestHeaders).apply { putAll(video.requestHeaders) }
            val enriched = existing.copy(
                pageUrl = video.pageUrl.ifBlank { existing.pageUrl },
                requestHeaders = mergedHeaders
            )
            if (enriched != existing) videos[video.url] = enriched
            return false
        }
        videos[video.url] = video
        return true
    }

    fun snapshot(): List<DetectedVideo> = videos.values.toList()
    val size: Int get() = videos.size
}
