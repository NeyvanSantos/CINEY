package com.example.castlite.casting

/** Callbacks for remote playback state changes. */
interface CastTargetListener {
    fun onStatusChanged(state: PlaybackState)
    fun onPositionChanged(positionMs: Long, durationMs: Long)
    fun onError(message: String)
}
