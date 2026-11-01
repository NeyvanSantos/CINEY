package com.example.castlite

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState as AndroidState
import android.os.*
import android.net.wifi.WifiManager
import com.example.castlite.casting.CastProtocol
import androidx.core.content.ContextCompat
import com.example.castlite.casting.CastTarget
import com.example.castlite.casting.PlaybackState
import com.example.castlite.casting.google.GoogleCastTarget

/** A transmissão e seus controles sobrevivem ao fechamento das telas. */
class CastingService : Service() {
    private lateinit var session: MediaSession
    private lateinit var wakeLock: PowerManager.WakeLock
    private var wifiLock: WifiManager.WifiLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private var inactiveSince = 0L
    private var terminalError: String? = null
    private val refresh = object : Runnable {
        override fun run() {
            val device = target
            if (device == null) { stopSelf(); return }
            (device as? GoogleCastTarget)?.refreshSession()
            val state = device.playbackState
            val now = SystemClock.elapsedRealtime()
            if (state == PlaybackState.PLAYING && mediaWasAccepted) hasPlayed = true
            val monitor = playbackIntent.shouldMonitor(state, now)
            if (!sourceNeedsReopen && monitor && accessGuard.observe(now, state, device.positionMs)) {
                sourceNeedsReopen = true
                sourceBlockedAt = now
                lastResumePosition = recovery?.positionMs ?: device.positionMs.takeIf { it > 0 } ?: lastResumePosition
                recovery = null
                if (state == PlaybackState.PLAYING) device.pause()
            }
            if (sourceNeedsReopen) {
                CastSessionEvents.error("source_access_denied")
                if (now - sourceBlockedAt >= 180_000) { terminalError = "source_access_denied"; stopSelf(); return }
            }
            val watchdog = recovery
            if (watchdog != null && device.reportsTransportState && (monitor || state == PlaybackState.PAUSED)) {
                val action = watchdog.observe(SystemClock.elapsedRealtime(), device.isConnected,
                    state, if (mediaWasAccepted) device.positionMs else 0L,
                    if (hasPlayed) device.durationMs else 0L,
                    device.recoverableIdle, loadFailed, !hasPlayed)
                when (action) {
                    PlaybackRecovery.Action.RELOAD -> reloadMedia(device, watchdog.positionMs)
                    PlaybackRecovery.Action.EXHAUSTED -> {
                        terminalError = "recovery_exhausted"
                        if (device.isConnected) device.stop()
                        stopSelf()
                        return
                    }
                    else -> Unit
                }
            }
            val inactive = device.isConnected && hasPlayed && !device.recoverableIdle &&
                state == PlaybackState.IDLE && !loadFailed
            if (!inactive) inactiveSince = 0L
            else if (inactiveSince == 0L) inactiveSince = SystemClock.elapsedRealtime()
            else if (SystemClock.elapsedRealtime() - inactiveSince > 60_000L) { stopSelf(); return }
            if (mediaWasAccepted && pendingSeekMs > 0 && device.playbackState in listOf(PlaybackState.PLAYING, PlaybackState.PAUSED)) {
                val position = if (device.durationMs > 0) pendingSeekMs.coerceAtMost((device.durationMs - 1000).coerceAtLeast(0))
                    else pendingSeekMs
                pendingSeekMs = 0L
                seekTo(position)
            }
            CastSessionEvents.update(device)
            if (sourceNeedsReopen) CastSessionEvents.error("source_access_denied")
            updateNotification()
            handler.postDelayed(this, 2_000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Transmissão para TV", NotificationManager.IMPORTANCE_LOW)
            )
        }
        session = MediaSession(this, "CastLite").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() { setUserPaused(false); target?.play() }
                override fun onPause() { setUserPaused(true); target?.pause() }
                override fun onSeekTo(pos: Long) { seekTo(pos.coerceAtLeast(0)) }
                override fun onStop() { stopCasting() }
            })
            isActive = true
        }
        wakeLock = getSystemService(PowerManager::class.java).newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK, "CastLite:relay"
        ).apply { acquire(6 * 60 * 60 * 1000L) }
        @Suppress("DEPRECATION")
        wifiLock = applicationContext.getSystemService(WifiManager::class.java)
            ?.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "CastLite:stream")
            ?.apply { setReferenceCounted(false); acquire() }
        startForeground(NOTIFICATION_ID, notification())
        handler.post(refresh)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == null) inactiveSince = 0L
        when (intent?.action) {
            "pause" -> { setUserPaused(true); target?.pause() }
            "play" -> { setUserPaused(false); target?.play() }
            "back" -> target?.let { seekTo((it.positionMs - 10_000).coerceAtLeast(0)) }
            "stop" -> stopCasting()
        }
        if (target == null) stopSelf() else updateNotification()
        // URLs temporárias não podem ser restauradas após a morte do processo.
        return START_NOT_STICKY
    }

    private fun stopCasting() { recovery = null; target?.stop(); stopSelf() }

    private fun reloadMedia(device: CastTarget, position: Long) {
        val video = media ?: return
        val relay = proxy ?: return
        val generation = ++loadGeneration
        bindRelayEvents(relay, generation)
        val resumed = video.copy(resumePositionMs = position)
        hasPlayed = false
        mediaWasAccepted = false
        loadFailed = false
        pendingSeekMs = if (device.protocol == CastProtocol.GOOGLE_CAST) 0L else position
        android.util.Log.i("CastLite-Recovery", "Reloading media at positionMs=$position protocol=${device.protocol}")
        try {
            device.loadMedia(resumed, relay, userAgent) { success ->
                handler.post {
                    if (target === device && generation == loadGeneration) {
                        mediaWasAccepted = success
                        loadFailed = !success
                    }
                }
            }
        } catch (error: Exception) {
            loadFailed = true
            android.util.Log.w("CastLite-Recovery", "Reload failed: ${error.javaClass.simpleName}")
        }
    }

    private fun updateNotification() {
        val device = target ?: return
        val state = when (device.playbackState) {
            PlaybackState.PLAYING -> AndroidState.STATE_PLAYING
            PlaybackState.PAUSED -> AndroidState.STATE_PAUSED
            PlaybackState.LOADING, PlaybackState.BUFFERING -> AndroidState.STATE_BUFFERING
            PlaybackState.ERROR -> AndroidState.STATE_ERROR
            else -> AndroidState.STATE_STOPPED
        }
        session.setPlaybackState(AndroidState.Builder().setActions(
            AndroidState.ACTION_PLAY or AndroidState.ACTION_PAUSE or AndroidState.ACTION_STOP or AndroidState.ACTION_SEEK_TO
        ).setState(state, device.positionMs, if (state == AndroidState.STATE_PLAYING) 1f else 0f).build())
        session.setMetadata(MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putLong(MediaMetadata.METADATA_KEY_DURATION, device.durationMs).build())
        if (Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification())
        }
    }

    private fun notification(): Notification {
        val playing = target?.playbackState == PlaybackState.PLAYING
        fun action(name: String): PendingIntent = PendingIntent.getService(this, name.hashCode(),
            Intent(this, CastingService::class.java).setAction(name), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val open = PendingIntent.getActivity(this, 0, Intent(this, RemoteControlActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        return builder
            .setSmallIcon(R.drawable.ic_launcher).setContentTitle(title)
            .setContentText(target?.name ?: "Transmissão para TV").setContentIntent(open)
            .setOnlyAlertOnce(true).setOngoing(true)
            .addAction(Notification.Action.Builder(android.R.drawable.ic_media_rew, "Voltar 10 s", action("back")).build())
            .addAction(Notification.Action.Builder(if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (playing) "Pausar" else "Reproduzir", action(if (playing) "pause" else "play")).build())
            .addAction(Notification.Action.Builder(android.R.drawable.ic_menu_close_clear_cancel, "Parar", action("stop")).build())
            .setStyle(Notification.MediaStyle().setMediaSession(session.sessionToken).setShowActionsInCompactView(0, 1, 2))
            .build()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        session.release()
        if (wakeLock.isHeld) wakeLock.release()
        wifiLock?.let { if (it.isHeld) it.release() }
        wifiLock = null
        loadGeneration++
        target?.takeIf { it.protocol != CastProtocol.GOOGLE_CAST }?.disconnect()
        recovery = null
        lastResumePosition = 0L
        reopenRequest = null
        playbackIntent = PlaybackIntent()
        media = null
        userAgent = ""
        if (releaseResources != null) (target as? GoogleCastTarget)?.detachClient()
        target = null
        pendingSeekMs = 0L
        mediaWasAccepted = false
        CastSessionEvents.update(null)
        terminalError?.let { CastSessionEvents.error(it) }
        proxy?.close()
        proxy = null
        releaseResources?.invoke()
        releaseResources = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?) = null

    companion object {
        private const val CHANNEL = "ciney.castlite.session"
        private const val NOTIFICATION_ID = 4242
        var target: CastTarget? = null
            private set
        private var proxy: LocalMediaProxy? = null
        private var title = "CastLite"
        private var releaseResources: (() -> Unit)? = null
        private var pendingSeekMs = 0L
        private var mediaWasAccepted = false
        private var media: DetectedVideo? = null
        private var userAgent = ""
        private var recovery: PlaybackRecovery? = null
        private var hasPlayed = false
        private var loadFailed = false
        private var loadGeneration = 0L
        private var playbackIntent = PlaybackIntent()
        private var accessGuard = SourceAccessGuard()
        private var sourceNeedsReopen = false
        private var sourceBlockedAt = 0L
        private var lastResumePosition = 0L
        private var reopenRequest: CastRequest? = null

        private fun bindRelayEvents(relay: LocalMediaProxy, generation: Long) {
            val ui = Handler(Looper.getMainLooper())
            relay.onAccessDenied = {
                ui.post { if (proxy === relay && loadGeneration == generation) accessGuard.denied(SystemClock.elapsedRealtime()) }
            }
            relay.onQualityRequested = { quality ->
                ui.post { if (proxy === relay && loadGeneration == generation) CastSessionEvents.quality(quality) }
            }
        }

        fun sourceRequest(): CastRequest? = reopenRequest?.copy(positionMs =
            recovery?.positionMs ?: target?.positionMs?.takeIf { it > 0 } ?: lastResumePosition)

        fun needsSourceAction(): Boolean = sourceNeedsReopen && target != null

        fun seekTo(position: Long) {
            val device = target ?: return
            val destination = if (device.durationMs > 0) position.coerceIn(0, (device.durationMs - 1000).coerceAtLeast(0))
                else position.coerceAtLeast(0)
            if (device.protocol != CastProtocol.ROKU) recovery?.seekTo(SystemClock.elapsedRealtime(), destination)
            lastResumePosition = destination
            device.seek(destination)
        }

        fun setUserPaused(paused: Boolean) {
            playbackIntent.requestPause(paused, SystemClock.elapsedRealtime())
            if (!paused && !sourceNeedsReopen) recovery = PlaybackRecovery(SystemClock.elapsedRealtime(),
                target?.positionMs ?: recovery?.positionMs ?: 0L)
        }

        fun mediaFailed(device: CastTarget, generation: Long) {
            if (target === device && generation == loadGeneration) loadFailed = true
        }

        fun mediaAccepted(device: CastTarget, generation: Long) {
            if (target === device && generation == loadGeneration) { mediaWasAccepted = true; loadFailed = false }
        }

        fun owns(value: LocalMediaProxy) = proxy === value

        fun isCurrentLoad(device: CastTarget, relay: LocalMediaProxy, generation: Long) =
            target === device && owns(relay) && loadGeneration == generation

        fun retainCleanup(value: LocalMediaProxy, cleanup: () -> Unit) {
            if (owns(value)) releaseResources = cleanup else cleanup()
        }

        fun start(context: Context, device: CastTarget, relay: LocalMediaProxy, video: DetectedVideo, fallbackUserAgent: String, resumePositionMs: Long = 0, request: CastRequest? = null): Long {
            if (target !== device) (target as? GoogleCastTarget)?.detachClient()
            if (proxy !== relay) { proxy?.close(); releaseResources?.invoke(); releaseResources = null }
            // A limpeza da tela anterior pode ter removido os callbacks deste alvo reutilizado.
            (device as? GoogleCastTarget)?.attachClient()
            target = device
            proxy = relay
            title = video.title
            media = video
            userAgent = fallbackUserAgent
            recovery = PlaybackRecovery(SystemClock.elapsedRealtime(), video.resumePositionMs)
            loadGeneration++
            bindRelayEvents(relay, loadGeneration)
            reopenRequest = request
            lastResumePosition = video.resumePositionMs
            playbackIntent = PlaybackIntent()
            accessGuard = SourceAccessGuard()
            sourceNeedsReopen = false
            hasPlayed = false
            loadFailed = false
            pendingSeekMs = resumePositionMs.coerceAtLeast(0)
            mediaWasAccepted = false
            try {
                ContextCompat.startForegroundService(context, Intent(context, CastingService::class.java))
            } catch (error: Exception) {
                target = null
                proxy = null
                recovery = null
                media = null
                userAgent = ""
                pendingSeekMs = 0L
                throw error
            }
            return loadGeneration
        }
    }
}
