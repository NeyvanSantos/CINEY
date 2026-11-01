package com.cinemax.cinemax

/** One inactivity deadline, independent of playback state or focused controls. */
internal class TvControlsAutoHide(
    private val postDelayed: (Runnable, Long) -> Unit,
    private val remove: (Runnable) -> Unit,
    private val hide: () -> Unit,
) {
    private var released = false
    private var touching = false
    private val timeout = Runnable { if (!released && !touching) hide() }

    fun onInteraction() {
        remove(timeout)
        if (!released && !touching) postDelayed(timeout, TIMEOUT_MS.toLong())
    }

    fun onTouchStarted() {
        touching = true
        remove(timeout)
    }

    fun onTouchFinished() {
        touching = false
        onInteraction()
    }

    fun onHidden() { remove(timeout) }

    fun release() {
        released = true
        remove(timeout)
    }

    companion object { const val TIMEOUT_MS = 5000 }
}
