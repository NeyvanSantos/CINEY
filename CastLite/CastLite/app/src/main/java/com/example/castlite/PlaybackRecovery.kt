package com.example.castlite

import com.example.castlite.casting.PlaybackState

/** Monotonic-time watchdog. Pauses and normal completion never reload media. */
internal class PlaybackRecovery(startedAt: Long, positionMs: Long) {
    enum class Action { WAIT, RELOAD, EXHAUSTED }
    var positionMs = positionMs.coerceAtLeast(0)
        private set
    private var lastProgressAt = startedAt
    private var lastAttemptAt = startedAt
    private var stableSince: Long? = null
    private var attempts = 0
    private var seekPending = false

    fun seekTo(now: Long, destination: Long) {
        positionMs = destination.coerceAtLeast(0)
        seekPending = true
        lastProgressAt = now
        stableSince = null
    }

    fun observe(now: Long, connected: Boolean, state: PlaybackState, position: Long,
                duration: Long, recoverableIdle: Boolean, loadFailed: Boolean, starting: Boolean = false): Action {
        if (seekPending && kotlin.math.abs(position - positionMs) <= 2000 &&
            state in listOf(PlaybackState.PLAYING, PlaybackState.PAUSED)) seekPending = false
        if (state == PlaybackState.PAUSED) {
            lastProgressAt = now
            stableSince = null
            return Action.WAIT
        }
        if (!seekPending && state == PlaybackState.BUFFERING && connected && position > 0) positionMs = position
        if (!seekPending && state == PlaybackState.PLAYING && connected && position > 0 && position != positionMs) {
            positionMs = position
            lastProgressAt = now
            val stable = stableSince ?: now.also { stableSince = it }
            if (now - stable >= 30_000) attempts = 0
            return Action.WAIT
        }
        stableSince = null
        val finished = !seekPending && state == PlaybackState.IDLE && duration > 0 && positionMs >= duration - 2_000
        if (finished || (connected && state == PlaybackState.IDLE && !recoverableIdle && !loadFailed && !starting)) return Action.WAIT
        val timeout = if (loadFailed || state == PlaybackState.ERROR || recoverableIdle && !starting) 8_000L else 45_000L
        if (now - lastProgressAt < timeout || now - lastAttemptAt < timeout) return Action.WAIT
        if (attempts >= 3 || now - lastProgressAt >= 180_000 && !connected) return Action.EXHAUSTED
        // The Cast SDK reconnects the session. Do not send LOAD while disconnected.
        if (!connected) return Action.WAIT
        attempts++
        lastAttemptAt = now
        return Action.RELOAD
    }
}
