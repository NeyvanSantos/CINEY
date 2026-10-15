package com.example.castlite

import android.net.Uri

data class DetectedVideo(
    val url: String,
    val title: String,
    val pageUrl: String,
    val mimeType: String,
    /** Headers relevantes mantidos apenas em memória para o relay de mídia Cast. */
    val requestHeaders: Map<String, String> = emptyMap(),
    /** True when the video is detected as DRM-protected and cannot be cast. */
    val isDrm: Boolean = false,
    val posterUrl: String? = null,
    val audioLanguage: String? = null,
    val resumePositionMs: Long = 0L
) {
    val label: String
        get() = "${VideoDetector.typeName(mimeType)} · ${Uri.parse(url).lastPathSegment ?: title}\n${Uri.parse(url).host}"
}
