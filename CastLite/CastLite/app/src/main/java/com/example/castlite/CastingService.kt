package com.example.castlite

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState as AndroidState
import android.os.*
import androidx.core.content.ContextCompat
import com.example.castlite.casting.CastTarget
import com.example.castlite.casting.PlaybackState
import com.example.castlite.casting.google.GoogleCastTarget

/** A transmissão e seus controles sobrevivem ao fechamento das telas. */
class CastingService : Service() {
    private lateinit var session: MediaSession
    private lateinit var wakeLock: PowerManager.WakeLock
    private val handler = Handler(Looper.getMainLooper())
    private var inactiveSince = 0L
    private val refresh = object : Runnable {
        override fun run() {
            val device = target
            if (device == null) { stopSelf(); return }
            val inactive = !device.isConnected || device.playbackState in listOf(PlaybackState.IDLE, PlaybackState.ERROR)
            if (!inactive) inactiveSince = 0L
            else if (inactiveSince == 0L) inactiveSince = SystemClock.elapsedRealtime()
            else if (SystemClock.elapsedRealtime() - inactiveSince > 60_000L) { stopSelf(); return }
            if (mediaWasAccepted && pendingSeekMs > 0 && device.playbackState in listOf(PlaybackState.PLAYING, PlaybackState.PAUSED)) {
                val position = if (device.durationMs > 0) pendingSeekMs.coerceAtMost((device.durationMs - 1000).coerceAtLeast(0))
                    else pendingSeekMs
                pendingSeekMs = 0L
                device.seek(position)
            }
            CastSessionEvents.update(device)
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
                override fun onPlay() { target?.play() }
                override fun onPause() { target?.pause() }
                override fun onSeekTo(pos: Long) { target?.seek(pos.coerceAtLeast(0)) }
                override fun onStop() { stopCasting() }
            })
            isActive = true
        }
        wakeLock = getSystemService(PowerManager::class.java).newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK, "CastLite:relay"
        ).apply { acquire(6 * 60 * 60 * 1000L) }
        startForeground(NOTIFICATION_ID, notification())
        handler.post(refresh)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == null) inactiveSince = 0L
        when (intent?.action) {
            "pause" -> target?.pause()
            "play" -> target?.play()
            "back" -> target?.let { it.seek((it.positionMs - 10_000).coerceAtLeast(0)) }
            "stop" -> stopCasting()
        }
        if (target == null) stopSelf() else updateNotification()
        // URLs temporárias não podem ser restauradas após a morte do processo.
        return START_NOT_STICKY
    }

    private fun stopCasting() { target?.stop(); stopSelf() }

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
        if (releaseResources != null) (target as? GoogleCastTarget)?.detachClient()
        target = null
        pendingSeekMs = 0L
        mediaWasAccepted = false
        CastSessionEvents.update(null)
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

        fun mediaAccepted(device: CastTarget) {
            if (target === device) mediaWasAccepted = true
        }

        fun owns(value: LocalMediaProxy) = proxy === value

        fun retainCleanup(value: LocalMediaProxy, cleanup: () -> Unit) {
            if (owns(value)) releaseResources = cleanup else cleanup()
        }

        fun start(context: Context, device: CastTarget, relay: LocalMediaProxy, mediaTitle: String, resumePositionMs: Long = 0) {
            if (target !== device) (target as? GoogleCastTarget)?.detachClient()
            if (proxy !== relay) { proxy?.close(); releaseResources?.invoke(); releaseResources = null }
            // A limpeza da tela anterior pode ter removido os callbacks deste alvo reutilizado.
            (device as? GoogleCastTarget)?.attachClient()
            target = device
            proxy = relay
            title = mediaTitle
            pendingSeekMs = resumePositionMs.coerceAtLeast(0)
            mediaWasAccepted = false
            try {
                ContextCompat.startForegroundService(context, Intent(context, CastingService::class.java))
            } catch (error: Exception) {
                target = null
                proxy = null
                pendingSeekMs = 0L
                throw error
            }
        }
    }
}
