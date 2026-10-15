package com.example.castlite.casting

import com.example.castlite.DetectedVideo
import com.example.castlite.LocalMediaProxy

/** Protocol type for display and icon selection. */
enum class CastProtocol { GOOGLE_CAST, DLNA, ROKU }

/**
 * Unified interface for all casting protocols.
 * Each implementation (Google Cast, DLNA, Roku) provides the same contract
 * so the UI layer doesn't need to know which protocol is in use.
 */
interface CastTarget {
    /** Human-readable device name (e.g. "Sala TV", "Roku Ultra"). */
    val name: String

    /** Which protocol this target uses. */
    val protocol: CastProtocol

    /** Current playback state. */
    val playbackState: PlaybackState

    /** Whether the target is currently connected and ready. */
    val isConnected: Boolean

    /** Approximate stream position in milliseconds. */
    val positionMs: Long

    /** Stream duration in milliseconds, or 0 if unknown. */
    val durationMs: Long

    /** Connect to the target device. */
    fun connect()

    /** Disconnect from the target device. */
    fun disconnect()

    /**
     * Load and start playing a detected video on the target.
     * Implementations should use [mediaProxy] to create a relay URL if needed.
     * @param video the video to cast
     * @param mediaProxy relay for cookies/headers
     * @param fallbackUserAgent user agent from the WebView
     * @param onResult callback with true on success, false on failure
     */
    fun loadMedia(
        video: DetectedVideo,
        mediaProxy: LocalMediaProxy,
        fallbackUserAgent: String,
        onResult: (Boolean) -> Unit
    )

    fun play()
    fun pause()
    fun stop()

    /** Seek to absolute position in milliseconds. */
    fun seek(positionMs: Long)

    /** Device volume is supported only by targets that expose a volume channel. */
    val supportsVolumeControl: Boolean get() = false
    fun adjustVolume(steps: Int): Boolean = false
    fun toggleMute(): Boolean = false

    /** Navigation keys (arrows, select, home/back/info) are protocol-specific. */
    val supportsRemoteNavigation: Boolean get() = false
    fun sendRemoteKey(key: String): Boolean = false

    fun addListener(listener: CastTargetListener)
    fun removeListener(listener: CastTargetListener)
}
