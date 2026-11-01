package com.cinemax.cinemax

import java.util.concurrent.atomic.AtomicBoolean

/** Authentication can be required by later segments or seeks, after first frame. */
internal class TvBrowserSessionState {
    private val required = AtomicBoolean(true)
    fun requireBrowser() { required.set(true) }
    fun canReleaseBrowser(firstFrame: Boolean, playbackReady: Boolean): Boolean =
        firstFrame && playbackReady && !required.get()
}

internal data class TvVideoRendition(
    val group: Int, val track: Int, val width: Int, val height: Int,
    val bitrate: Int, val supported: Boolean = true,
)

internal object TvPlaybackOptions {
    fun available(renditions: List<TvVideoRendition>): List<TvVideoRendition> = renditions
        .filter { it.supported && it.width > 0 && it.height > 0 }
        .sortedWith(compareByDescending<TvVideoRendition> { it.height }
            .thenByDescending { it.bitrate }.thenByDescending { it.width })
        .distinctBy { it.height }

    fun brightness(progress: Int): Float = progress.coerceIn(0, 100) / 100f * 0.30f
}
