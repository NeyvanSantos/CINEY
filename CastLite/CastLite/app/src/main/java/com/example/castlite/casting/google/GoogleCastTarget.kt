package com.example.castlite.casting.google

import android.content.Context
import android.net.Uri
import android.util.Log
import com.example.castlite.DetectedVideo
import com.example.castlite.CastSource
import com.example.castlite.LocalMediaProxy
import com.example.castlite.R
import com.example.castlite.SimpleSessionListener
import com.example.castlite.casting.CastProtocol
import com.example.castlite.casting.CastTarget
import com.example.castlite.casting.CastTargetListener
import com.example.castlite.casting.PlaybackState
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaStatus
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.images.WebImage
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors

/**
 * Google Cast implementation of [CastTarget].
 * Wraps CastContext, CastSession and RemoteMediaClient behind the unified interface.
 */
class GoogleCastTarget private constructor(
    override val name: String,
    private var session: CastSession,
    private val appContext: Context
) : CastTarget {

    override val protocol = CastProtocol.GOOGLE_CAST

    override val supportsVolumeControl: Boolean get() = isConnected

    private val listeners = CopyOnWriteArrayList<CastTargetListener>()
    private var observedClient: RemoteMediaClient? = null
    private var loading = false
    private var loadEpoch = 0L

    private val mediaCallback = object : RemoteMediaClient.Callback() {
        override fun onStatusUpdated() = notifyStatus()
    }

    private val progressListener = RemoteMediaClient.ProgressListener { position, duration ->
        listeners.forEach { it.onPositionChanged(position.coerceAtLeast(0L), duration.coerceAtLeast(0L)) }
    }

    override val isConnected: Boolean get() = session.isConnected

    override val recoverableIdle: Boolean
        get() = session.remoteMediaClient?.mediaStatus?.idleReason == MediaStatus.IDLE_REASON_ERROR

    fun matchesSession(value: CastSession): Boolean = session === value

    /** Session restoration must keep working when the browser Activity is gone. */
    internal fun refreshSession() {
        val restored = CastContext.getSharedInstance(appContext).sessionManager.currentCastSession ?: return
        if (restored !== session && restored.isConnected &&
            restored.castDevice?.deviceId == session.castDevice?.deviceId) {
            session = restored
        }
        if (session.isConnected) attachClient()
    }

    override val playbackState: PlaybackState
        get() {
            val client = session.remoteMediaClient ?: return PlaybackState.IDLE
            return when (client.playerState) {
                MediaStatus.PLAYER_STATE_PLAYING -> PlaybackState.PLAYING
                MediaStatus.PLAYER_STATE_PAUSED -> PlaybackState.PAUSED
                MediaStatus.PLAYER_STATE_BUFFERING -> PlaybackState.BUFFERING
                MediaStatus.PLAYER_STATE_IDLE -> if (loading) PlaybackState.LOADING else PlaybackState.IDLE
                else -> if (loading) PlaybackState.LOADING else PlaybackState.IDLE
            }
        }

    override val positionMs: Long
        get() = session.remoteMediaClient?.approximateStreamPosition?.coerceAtLeast(0L) ?: 0L

    override val durationMs: Long
        get() = session.remoteMediaClient?.mediaInfo?.streamDuration?.coerceAtLeast(0L) ?: 0L

    override fun connect() {
        // Google Cast manages connections via MediaRouteButton / CastContext dialog.
        // This is a no-op; the session is already connected when this target is created.
    }

    override fun disconnect() {
        loadEpoch++
        loading = false
        detachClient()
        try { session.remoteMediaClient?.stop() } catch (_: Exception) {}
    }

    override fun loadMedia(
        video: DetectedVideo,
        mediaProxy: LocalMediaProxy,
        fallbackUserAgent: String,
        onResult: (Boolean) -> Unit
    ) {
        val generation = ++loadEpoch
        val client = session.remoteMediaClient
        if (client == null || !session.isConnected) {
            onResult(false)
            return
        }
        val mediaUrl = mediaProxy.createMediaUrl(video, fallbackUserAgent)
        Log.d("CastLite-Cast", "Loading mime=${video.mimeType} relay=${mediaUrl != null}")
        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE).apply {
            putString(MediaMetadata.KEY_TITLE, video.title)
            video.posterUrl?.takeIf { CastSource.isWebUrl(it) }?.let { addImage(WebImage(Uri.parse(it))) }
        }
        val mediaInfo = MediaInfo.Builder(mediaUrl ?: video.url)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(video.mimeType)
            .setMetadata(metadata)
            .build()
        val request = MediaLoadRequestData.Builder()
            .setMediaInfo(mediaInfo)
            .setAutoplay(true)
            .setCurrentTime(video.resumePositionMs.coerceAtLeast(0))
            .build()
        try {
            loading = true
            client.load(request).setResultCallback { result ->
                if (generation != loadEpoch) return@setResultCallback
                loading = false
                Log.d("CastLite-Cast", "Load result=${result.status.statusCode}")
                onResult(result.status.isSuccess)
                notifyStatus()
            }
        } catch (_: Exception) {
            loading = false
            onResult(false)
        }
    }

    override fun play() = runSafe {
        session.remoteMediaClient?.play()?.setResultCallback { r ->
            if (!r.status.isSuccess) listeners.forEach { it.onError(appContext.getString(R.string.cast_command_error)) }
        }
    }

    override fun pause() = runSafe {
        session.remoteMediaClient?.pause()?.setResultCallback { r ->
            if (!r.status.isSuccess) listeners.forEach { it.onError(appContext.getString(R.string.cast_command_error)) }
        }
    }

    override fun stop() = runSafe {
        loadEpoch++
        loading = false
        session.remoteMediaClient?.stop()?.setResultCallback { r ->
            if (!r.status.isSuccess) listeners.forEach { it.onError(appContext.getString(R.string.cast_command_error)) }
            notifyStatus()
        }
    }

    override fun seek(positionMs: Long) = runSafe {
        session.remoteMediaClient?.seek(positionMs)?.setResultCallback { r ->
            if (!r.status.isSuccess) listeners.forEach { it.onError(appContext.getString(R.string.control_seek_failed)) }
        }
    }

    override fun adjustVolume(steps: Int): Boolean {
        if (steps == 0) return false
        val client = session.remoteMediaClient ?: return false
        val current = client.mediaStatus?.streamVolume ?: return false
        val next = (current + steps.coerceIn(-5, 5) * VOLUME_STEP).coerceIn(0.0, 1.0)
        return try {
            client.setStreamVolume(next).setResultCallback { result ->
                if (!result.status.isSuccess) listeners.forEach { it.onError(appContext.getString(R.string.cast_command_error)) }
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun toggleMute(): Boolean {
        val client = session.remoteMediaClient ?: return false
        val status = client.mediaStatus ?: return false
        return try {
            client.setStreamMute(!status.isMute).setResultCallback { result ->
                if (!result.status.isSuccess) listeners.forEach { it.onError(appContext.getString(R.string.cast_command_error)) }
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun addListener(listener: CastTargetListener) {
        listeners.add(listener)
        attachClient()
    }

    override fun removeListener(listener: CastTargetListener) {
        listeners.remove(listener)
        if (listeners.isEmpty()) detachClient()
    }

    /** Whether the remote player has active media (not idle). */
    fun hasActiveMedia(): Boolean {
        val client = session.remoteMediaClient ?: return false
        return client.mediaInfo != null && client.playerState != MediaStatus.PLAYER_STATE_IDLE
    }

    fun isPlaying(): Boolean = session.remoteMediaClient?.isPlaying == true

    // --- internal ---

    internal fun attachClient() {
        val client = session.remoteMediaClient ?: return
        if (observedClient !== client) {
            observedClient?.unregisterCallback(mediaCallback)
            observedClient?.removeProgressListener(progressListener)
            observedClient = client
            client.registerCallback(mediaCallback)
            client.addProgressListener(progressListener, PROGRESS_INTERVAL_MS)
        }
    }

    internal fun detachClient() {
        observedClient?.unregisterCallback(mediaCallback)
        observedClient?.removeProgressListener(progressListener)
        observedClient = null
    }

    internal fun notifyStatus() {
        val state = playbackState
        Log.d("CastLite-Cast", "State=$state idleReason=${session.remoteMediaClient?.mediaStatus?.idleReason} position=$positionMs duration=$durationMs")
        listeners.forEach { it.onStatusChanged(state) }
    }

    private fun runSafe(block: () -> Unit) {
        try { block() } catch (_: Exception) {
            listeners.forEach { it.onError(appContext.getString(R.string.cast_command_error)) }
        }
    }

    companion object {
        private const val PROGRESS_INTERVAL_MS = 1_000L
        private const val VOLUME_STEP = 0.05
        private val castExecutor = Executors.newSingleThreadExecutor()

        /** Create a GoogleCastTarget from an active CastSession. Returns null if not connected. */
        fun fromSession(session: CastSession, appContext: Context): GoogleCastTarget? {
            if (!session.isConnected) return null
            val name = session.castDevice?.friendlyName ?: "Chromecast"
            return GoogleCastTarget(name, session, appContext)
        }

        /** Check if Google Play Services is available for Cast. */
        fun isAvailable(context: Context): Boolean {
            return try {
                GoogleApiAvailability.getInstance()
                    .isGooglePlayServicesAvailable(context) == ConnectionResult.SUCCESS
            } catch (_: Exception) {
                false
            }
        }

        /** Initialize CastContext asynchronously. */
        fun initializeCastContext(
            context: Context,
            onSuccess: (CastContext) -> Unit,
            onFailure: () -> Unit
        ) {
            try {
                CastContext.getSharedInstance(context.applicationContext, castExecutor)
                    .addOnSuccessListener { onSuccess(it) }
                    .addOnFailureListener { onFailure() }
            } catch (_: Exception) {
                onFailure()
            }
        }
    }
}
