package com.example.castlite

import java.net.URI

/** Contrato interno versionado; nunca interpreta um embed como arquivo direto. */
data class CastSource(
    val url: String,
    val server: String,
    val isEmbed: Boolean,
    val isDirect: Boolean,
    val mimeType: String?,
    val headers: Map<String, String>,
    val audioLanguage: String?
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "url" to url, "server" to server, "isEmbed" to isEmbed,
        "isDirect" to isDirect, "mimeType" to mimeType,
        "headers" to headers, "audioLanguage" to audioLanguage
    )

    companion object {
        fun fromMap(value: Map<*, *>): CastSource {
            val url = requireNotNull(value["url"] as? String) { "invalid_url" }
            require(isWebUrl(url)) { "invalid_url" }
            require(value["headers"] == null || value["headers"] is Map<*, *>) { "invalid_headers" }
            val rawHeaders = value["headers"] as? Map<*, *> ?: emptyMap<Any, Any>()
            require(rawHeaders.size <= 32) { "invalid_headers" }
            val headers = rawHeaders.entries.associate { (key, entry) ->
                require(key is String && key.matches(Regex("[A-Za-z0-9-]{1,64}"))) { "invalid_headers" }
                require(entry is String && entry.length <= 8192 && '\r' !in entry && '\n' !in entry) { "invalid_headers" }
                key to entry
            }
            val embed = value["isEmbed"] == true
            return CastSource(
                url, (value["server"] as? String).orEmpty().take(200), embed,
                !embed && value["isDirect"] == true,
                (value["mimeType"] as? String)?.takeIf { it.length <= 100 },
                headers, (value["audioLanguage"] as? String)?.takeIf { it.matches(Regex("[A-Za-z-]{2,16}")) }
            )
        }

        fun isWebUrl(value: String): Boolean = value.length <= 16384 && runCatching {
            val uri = URI(value)
            uri.scheme.lowercase() in listOf("http", "https") && !uri.host.isNullOrBlank() && uri.userInfo == null
        }.getOrDefault(false)
    }
}

data class CastRequest(
    val requestId: String,
    val title: String,
    val posterUrl: String,
    val positionMs: Long,
    val sourceIndex: Int,
    val sources: List<CastSource>,
    val contentId: String?,
    val season: Int?,
    val episode: Int?
) {
    val source: CastSource get() = sources[sourceIndex]

    fun toMap(): Map<String, Any?> = mapOf(
        "version" to 1, "requestId" to requestId, "title" to title,
        "posterUrl" to posterUrl, "positionMs" to positionMs,
        "sourceIndex" to sourceIndex, "sources" to sources.map { it.toMap() },
        "contentId" to contentId, "season" to season, "episode" to episode
    )

    companion object {
        const val EXTRA = "com.ciney.castlite.REQUEST"

        fun fromMap(value: Map<*, *>): CastRequest {
            require(value["version"] == 1) { "unsupported_version" }
            val requestId = requireNotNull(value["requestId"] as? String) { "invalid_request" }
            require(requestId.matches(Regex("[A-Za-z0-9_-]{1,100}"))) { "invalid_request" }
            val sources = requireNotNull(value["sources"] as? List<*>) { "invalid_sources" }
            require(sources.size in 1..32) { "invalid_sources" }
            val index = integer(value["sourceIndex"], 0, sources.lastIndex.toLong()).toInt()
            require(index in sources.indices) { "invalid_source_index" }
            val poster = (value["posterUrl"] as? String).orEmpty()
            require(poster.isEmpty() || CastSource.isWebUrl(poster)) { "invalid_poster" }
            return CastRequest(
                requestId, (value["title"] as? String).orEmpty().take(500), poster,
                integer(value["positionMs"], 0), index,
                sources.map { CastSource.fromMap(requireNotNull(it as? Map<*, *>) { "invalid_sources" }) },
                (value["contentId"] as? String)?.take(200),
                value["season"]?.let { integer(it, 1, Int.MAX_VALUE.toLong()).toInt() },
                value["episode"]?.let { integer(it, 1, Int.MAX_VALUE.toLong()).toInt() }
            )
        }

        private fun integer(value: Any?, minimum: Long, maximum: Long = Int.MAX_VALUE.toLong() * 1000): Long {
            require(value is Int || value is Long) { "invalid_number" }
            val number = (value as Number).toLong()
            require(number in minimum..maximum) { "invalid_number" }
            return number
        }
    }
}
