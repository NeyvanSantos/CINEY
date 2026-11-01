package com.example.castlite

import com.example.castlite.casting.PlaybackState

internal class SourceAccessGuard {
    private var deniedAt: Long? = null
    private var lastPosition = 0L
    fun denied(now: Long) { if (deniedAt == null) deniedAt = now }
    fun observe(now: Long, state: PlaybackState, position: Long): Boolean {
        if (state == PlaybackState.PLAYING && position > 0 && position != lastPosition) deniedAt = null
        lastPosition = position
        return deniedAt?.let { now - it >= 8000 && state != PlaybackState.PAUSED } ?: false
    }
}
