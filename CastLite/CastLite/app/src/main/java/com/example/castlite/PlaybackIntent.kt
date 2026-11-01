package com.example.castlite

import com.example.castlite.casting.PlaybackState

internal class PlaybackIntent {
    private var paused = false
    private var requestedAt = 0L
    private var confirmed = false
    fun requestPause(value: Boolean, now: Long) { paused = value; requestedAt = now; confirmed = false }
    fun shouldMonitor(state: PlaybackState, now: Long): Boolean {
        if (state == PlaybackState.PAUSED) { confirmed = true; return false }
        if (paused && (confirmed && state == PlaybackState.PLAYING || now - requestedAt >= 8000)) paused = false
        return !paused
    }
}
