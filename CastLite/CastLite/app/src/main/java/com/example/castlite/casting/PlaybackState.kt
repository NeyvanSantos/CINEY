package com.example.castlite.casting

/** Unified playback states across all casting protocols. */
enum class PlaybackState {
    IDLE,
    LOADING,
    PLAYING,
    PAUSED,
    BUFFERING,
    ERROR
}
