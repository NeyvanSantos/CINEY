package com.example.castlite

import java.net.URI
import java.util.Locale

object VideoDetector {
    /** Só links HTTP(S) podem ser carregados diretamente pelo receiver. */
    fun isHttpUrl(url: String): Boolean = httpUri(url) != null

    fun isVideoUrl(url: String): Boolean = mimeTypeFor(url) != null

    // A extensão vem do caminho, nunca da query. O link assinado original é preservado.
    fun mimeTypeFor(url: String, declaredType: String? = null): String? {
        val uri = httpUri(url) ?: return null
        declaredMimeType(declaredType)?.let { return it }
        val path = uri.path.orEmpty().lowercase(Locale.ROOT)
        val fullUrl = url.lowercase(Locale.ROOT)

        // 1. Extensão explícita no caminho
        val extResult = when (path.substringAfterLast('.')) {
            "mp4" -> "video/mp4"
            "m3u8" -> "application/x-mpegURL"
            "mpd" -> "application/dash+xml"
            "webm" -> "video/webm"
            "mkv" -> "video/x-matroska"
            "ts" -> if (path.contains("/video") || path.contains("/hls") || path.contains("/stream")) "video/mp2t" else null
            else -> null
        }
        if (extResult != null) return extResult

        // 2. Extensão em qualquer parte da URL (query string inclusa) - CDNs usam ?file=video.m3u8
        if (fullUrl.contains(".m3u8")) return "application/x-mpegURL"
        if (fullUrl.contains(".mpd")) return "application/dash+xml"
        // .mp4 na query é ambíguo com páginas que mencionam mp4; só aceitar se o path sugere mídia
        if (fullUrl.contains(".mp4") && (path.contains("/video") || path.contains("/stream") || path.contains("/media") || path.contains("/download"))) {
            return "video/mp4"
        }

        // 3. Padrões de URL de CDNs de vídeo conhecidos
        val host = uri.host.orEmpty().lowercase(Locale.ROOT)
        if (host.contains("googlevideo.com") || host.contains("akamaized.net") ||
            host.contains("cloudfront.net") || host.contains("cdn") || host.contains("stream")) {
            if (path.contains("/videoplayback") || path.contains("/hls") || path.contains("/dash") ||
                path.contains("/manifest") || path.contains("/playlist") || path.contains("/index")) {
                // Padrão de playlist HLS ou manifest DASH de CDN
                return if (path.contains("mpd") || path.contains("dash")) "application/dash+xml" else "application/x-mpegURL"
            }
        }

        return null
    }

    private fun declaredMimeType(type: String?): String? =
        when (type?.substringBefore(';')?.trim()?.lowercase(Locale.ROOT)) {
            "mp4", "video/mp4" -> "video/mp4"
            "hls", "m3u8", "application/x-mpegurl", "application/vnd.apple.mpegurl" -> "application/x-mpegURL"
            "dash", "mpd", "application/dash+xml" -> "application/dash+xml"
            "webm", "video/webm" -> "video/webm"
            "mkv", "video/x-matroska" -> "video/x-matroska"
            "video/mp2t" -> "video/mp2t"
            else -> null
        }

    fun typeName(mimeType: String): String = when (mimeType) {
        "application/x-mpegURL" -> "HLS"
        "application/dash+xml" -> "DASH"
        "video/webm" -> "WEBM"
        "video/mp2t" -> "TS"
        "video/x-matroska" -> "MKV"
        else -> "MP4"
    }

    private fun httpUri(url: String): URI? = try {
        URI(url).takeIf {
            (it.scheme.equals("http", true) || it.scheme.equals("https", true)) &&
                !it.host.isNullOrBlank() && it.rawUserInfo == null
        }
    } catch (_: Exception) {
        null
    }
}
