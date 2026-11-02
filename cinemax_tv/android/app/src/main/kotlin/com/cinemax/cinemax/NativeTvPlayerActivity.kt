package com.cinemax.cinemax

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.Toast
import androidx.media3.common.MediaItem
import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.VideoSize
import androidx.media3.effect.Brightness
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.DecoderReuseEvaluation
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView

/** Dedicated SurfaceView: video is composed by Android, outside Flutter. */
@androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
open class NativeTvPlayerActivity : Activity() {
    private lateinit var playerView: PlayerView
    private lateinit var controls: TvPlayerControls
    private var player: ExoPlayer? = null
    private var position = 0L
    private var resumePlaying = true
    private var duration = 0L
    private var failed = false
    private var completed = false
    private var sources = false
    private var readySent = false
    private var firstFrameRendered = false
    private var playbackPrepared = false
    private var brightness = 0
    private var effectsEnabled = false
    private var pendingBrightnessRedraw: Runnable? = null
    private var startGeneration = 0
    private val watchdog = Handler(Looper.getMainLooper())
    private val startupTimeout = Runnable {
        if (!playbackPrepared && !isFinishing) {
            Log.w("CINEY_NATIVE", "startupTimeout")
            if (!restoreOriginalImage()) { failed = true; finish() }
        }
    }
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        position = state?.getLong("positionMs") ?: intent.getLongExtra("positionMs", 0)
        resumePlaying = state?.getBoolean("playWhenReady", true) ?: true
        brightness = state?.getInt("brightness", 0) ?: 0
        effectsEnabled = brightness > 0
        // PlayerView uses SurfaceView by default. No Flutter platform-view layer.
        window.decorView.setBackgroundColor(android.graphics.Color.BLACK)
        playerView = PlayerView(this)
        playerView.setControllerAutoShow(false)
        playerView.controllerShowTimeoutMs = TvControlsAutoHide.TIMEOUT_MS
        playerView.setBackgroundColor(android.graphics.Color.BLACK)
        playerView.setShowNextButton(false)
        playerView.setShowPreviousButton(false)
        controls = TvPlayerControls(this, playerView, ::changeBrightness, ::showSources)
        controls.setBrightness(brightness)
        val content = FrameLayout(this)
        content.addView(playerView, FrameLayout.LayoutParams(-1, -1))
        content.addView(controls, FrameLayout.LayoutParams(-1, -1))
        setContentView(content)
        playerView.requestFocus()
    }
    override fun onStart() {
        super.onStart()
        if (player != null) return
        startPlayer(position, resumePlaying)
    }
    private fun startPlayer(startPosition: Long, startPlaying: Boolean) {
        val generation = ++startGeneration
        val browser = MainActivity.activeTransport
        val page = intent.getStringExtra("pageUrl")
        if (browser != null && page != null) {
            browser.pauseLocalPlayback(page) { stopped ->
                if (generation != startGeneration || isFinishing || isDestroyed) return@pauseLocalPlayback
                Log.i("CINEY_NATIVE", "browserPlaybackStopped=$stopped")
                if (!stopped) {
                    failed = true
                    finish()
                } else preparePlayer(startPosition, startPlaying)
            }
        } else preparePlayer(startPosition, startPlaying)
    }
    private fun preparePlayer(startPosition: Long, startPlaying: Boolean) {
        firstFrameRendered = false
        playbackPrepared = false
        @Suppress("DEPRECATION", "UNCHECKED_CAST")
        val headers = intent.getSerializableExtra("headers") as? HashMap<String, String> ?: hashMapOf()
        val httpHeaders = if (intent.getBooleanExtra("browserSession", false))
            headers.filterKeys { !it.equals("Cookie", ignoreCase = true) } else headers
        val http = DefaultHttpDataSource.Factory().setDefaultRequestProperties(httpHeaders)
        val load = DefaultLoadControl.Builder()
            .setBufferDurationsMs(10000, 30000, 1500, 2500)
            .setTargetBufferBytes(24 * 1024 * 1024)
            .setPrioritizeTimeOverSizeThresholds(false).build()
        val browser = MainActivity.activeTransport
        val page = intent.getStringExtra("pageUrl")
        val session = TvBrowserSessionState()
        Log.i("CINEY_NATIVE", "transport=" + if (browser != null && page != null) "browser" else "http")
        val sourceFactory = if (browser != null && page != null) {
            browser.pauseLocalPlayback()
            // Browser cookies remain in the browser. Public CDN segments can
            // use fast native HTTP; 401/403 resources use the validated frame.
            val sessionHttp = DefaultHttpDataSource.Factory().setDefaultRequestProperties(
                headers.filterKeys { !it.equals("Cookie", ignoreCase = true) }
            )
            DefaultMediaSourceFactory(androidx.media3.datasource.DataSource.Factory {
                SessionHttpDataSource(
                    sessionHttp.createDataSource(), BrowserSessionDataSource(browser, page),
                    session::requireBrowser
                )
            })
        } else DefaultMediaSourceFactory(http)
        // Media3 decoder fallback allows recovering when hardware decoder fails on TV.
        val renderers = DefaultRenderersFactory(this)
            .setEnableDecoderFallback(true)
        val exo = ExoPlayer.Builder(this, renderers).setLoadControl(load)
            .setReleaseTimeoutMs(2000)
            .setMediaSourceFactory(sourceFactory).build()
        player = exo
        playerView.player = exo
        controls.bind(exo)
        fun notifyPrepared() {
            if (player !== exo || !firstFrameRendered || exo.playbackState != Player.STATE_READY) return
            playbackPrepared = true
            watchdog.removeCallbacks(startupTimeout)
            if (!readySent) {
                readySent = true
                MainActivity.activeHost?.nativePlayerReady(!session.canReleaseBrowser(true, true))
            }
        }
        if (effectsEnabled) {
            exo.setVideoEffects(if (brightness == 0) emptyList() else
                listOf(Brightness(TvPlaybackOptions.brightness(brightness))))
        }
        if (intent.getBooleanExtra("portuguese", true)) {
            exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                .setPreferredAudioLanguages("pt-BR", "pt", "por").build()
        }
        exo.addAnalyticsListener(object : AnalyticsListener {
            override fun onVideoInputFormatChanged(time: AnalyticsListener.EventTime, format: Format,
                decoderReuseEvaluation: DecoderReuseEvaluation?) {
                if (player !== exo) return
                controls.setVideoDimensions(format.width, format.height)
                Log.i("CINEY_NATIVE", "inputVideo=${format.width}x${format.height}")
            }
            override fun onVideoDecoderInitialized(time: AnalyticsListener.EventTime, name: String, timestamp: Long, durationMs: Long) {
                if (player !== exo) return
                Log.i("CINEY_NATIVE", "decoder=$name initMs=$durationMs")
            }
            override fun onDroppedVideoFrames(time: AnalyticsListener.EventTime, count: Int, elapsed: Long) {
                if (player !== exo) return
                Log.i("CINEY_NATIVE", "dropped=$count elapsedMs=$elapsed")
            }
            override fun onRenderedFirstFrame(time: AnalyticsListener.EventTime, output: Any, renderTimeMs: Long) {
                if (player !== exo) return
                Log.i("CINEY_NATIVE", "firstFrame")
                firstFrameRendered = true
                notifyPrepared()
            }
        })
        exo.addListener(object : Player.Listener {
            override fun onVideoSizeChanged(videoSize: VideoSize) {
                if (player !== exo) return
                exo.videoFormat?.let { format ->
                    Log.i("CINEY_NATIVE", "video=${format.width}x${format.height}")
                }
            }
            override fun onPlaybackStateChanged(state: Int) {
                if (player !== exo) return
                Log.i("CINEY_NATIVE", "state=$state bufferedMs=${exo.totalBufferedDuration}")
                if (exo.totalBufferedDuration > 0 && !playbackPrepared) {
                    watchdog.removeCallbacks(startupTimeout)
                    watchdog.postDelayed(startupTimeout, if (browser != null && page != null) 35000 else 20000)
                }
                notifyPrepared()
                if (state == Player.STATE_ENDED) { completed = true; finish() }
            }
            override fun onPlayerError(error: PlaybackException) {
                // A release timeout belongs to the decoder being discarded,
                // not to the replacement session started by a brightness change.
                if (player !== exo) return
                val chain = generateSequence<Throwable>(error) { it.cause }.take(6).joinToString(" > ") { cause ->
                    val detail = cause.message?.takeIf { it.startsWith("Browser ") || it == "Closed" || it == "Range outside resource" } ?: ""
                    cause.javaClass.simpleName + if (detail.isNotEmpty()) ":$detail" else ""
                }
                Log.e("CINEY_NATIVE", "errorCode=${error.errorCode} cause=$chain")
                if (generateSequence<Throwable>(error) { it.cause }
                    .any { it is VideoFrameProcessingException } && restoreOriginalImage()) return
                failed = true; finish()
            }
        })
        val mediaUri = android.net.Uri.parse(intent.getStringExtra("url")!!)
        val pathLower = mediaUri.path.orEmpty().lowercase(java.util.Locale.ROOT)
        val mediaItemBuilder = MediaItem.Builder().setUri(mediaUri)
        when {
            pathLower.endsWith(".m3u8") || pathLower.contains("m3u8") -> mediaItemBuilder.setMimeType(MimeTypes.APPLICATION_M3U8)
            pathLower.endsWith(".mpd") -> mediaItemBuilder.setMimeType(MimeTypes.APPLICATION_MPD)
            pathLower.endsWith(".mp4") -> mediaItemBuilder.setMimeType(MimeTypes.APPLICATION_MP4)
            pathLower.endsWith(".mkv") -> mediaItemBuilder.setMimeType(MimeTypes.VIDEO_MATROSKA)
            pathLower.endsWith(".webm") -> mediaItemBuilder.setMimeType(MimeTypes.VIDEO_WEBM)
            else -> mediaItemBuilder.setMimeType(MimeTypes.APPLICATION_M3U8)
        }
        exo.setMediaItem(mediaItemBuilder.build(), startPosition)
        watchdog.postDelayed(startupTimeout, if (browser != null && page != null) 45000 else 25000)
        exo.prepare()
        exo.playWhenReady = startPlaying
    }
    private fun changeBrightness(value: Int) {
        brightness = value.coerceIn(0, 100)
        val exo = player ?: return
        if (!effectsEnabled) {
            if (brightness == 0) return
            val playing = exo.playWhenReady
            snapshot()
            val restartAt = position
            releasePlayer()
            effectsEnabled = true
            Log.i("CINEY_NATIVE", "brightnessPipeline=enabled positionMs=$restartAt")
            startPlayer(restartAt, playing)
        } else {
            exo.setVideoEffects(if (brightness == 0) emptyList() else
                listOf(Brightness(TvPlaybackOptions.brightness(brightness))))
            pendingBrightnessRedraw?.let(watchdog::removeCallbacks)
            if (!exo.playWhenReady) {
                // Media3 1.9 has no redraw API. Coalesce paused changes into
                // one exact seek; a 1 ms increment avoids its same-position no-op.
                pendingBrightnessRedraw = Runnable {
                    if (player === exo && !exo.playWhenReady) {
                        val next = exo.currentPosition + 1
                        exo.seekTo(if (exo.duration > 1) minOf(next, exo.duration - 1) else next)
                    }
                }.also { watchdog.postDelayed(it, 300) }
            }
        }
        Log.i("CINEY_NATIVE", "brightness=$brightness")
    }
    private fun restoreOriginalImage(): Boolean {
        if (!effectsEnabled) return false
        val playing = player?.playWhenReady ?: true
        snapshot()
        val restartAt = position
        brightness = 0
        effectsEnabled = false
        controls.disableBrightness()
        Toast.makeText(this, "Esta TV não conseguiu aplicar o brilho. Imagem original restaurada.", Toast.LENGTH_LONG).show()
        watchdog.post {
            if (!isFinishing && player != null) {
                releasePlayer()
                startPlayer(restartAt, playing)
            }
        }
        return true
    }
    private fun showSources() { sources = true; finish() }
    private fun snapshot() {
        player?.let {
            position = it.currentPosition.coerceAtLeast(0)
            duration = it.duration.coerceAtLeast(0)
            resumePlaying = it.playWhenReady
        }
    }
    override fun onSaveInstanceState(out: Bundle) {
        snapshot(); out.putLong("positionMs", position)
        out.putBoolean("playWhenReady", resumePlaying)
        out.putInt("brightness", brightness)
        super.onSaveInstanceState(out)
    }
    override fun onStop() {
        startGeneration++
        watchdog.removeCallbacks(startupTimeout)
        snapshot()
        releasePlayer()
        super.onStop()
    }
    private fun releasePlayer() {
        watchdog.removeCallbacks(startupTimeout)
        pendingBrightnessRedraw?.let(watchdog::removeCallbacks)
        pendingBrightnessRedraw = null
        val previous = player ?: return
        player = null
        previous.videoDecoderCounters?.let { counters ->
            counters.ensureUpdated()
            Log.i("CINEY_NATIVE", "rendered=${counters.renderedOutputBufferCount} dropped=${counters.droppedBufferCount}")
        }
        controls.bind(null)
        playerView.player = null
        previous.release()
    }
    override fun onDestroy() {
        controls.release()
        super.onDestroy()
    }
    override fun finish() {
        snapshot()
        setResult(RESULT_OK, Intent().putExtra("positionMs", position)
            .putExtra("durationMs", duration).putExtra("error", failed)
            .putExtra("completed", completed).putExtra("sources", sources))
        super.finish()
    }
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (::controls.isInitialized) controls.onUserInteraction()
        if (event.keyCode == KeyEvent.KEYCODE_MENU) {
            if (event.action == KeyEvent.ACTION_UP) showSources()
            return true
        }
        if (controls.handleKey(event)) return true
        if (event.keyCode in intArrayOf(KeyEvent.KEYCODE_MEDIA_PLAY, KeyEvent.KEYCODE_MEDIA_PAUSE,
                KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_MEDIA_REWIND,
                KeyEvent.KEYCODE_MEDIA_FAST_FORWARD, KeyEvent.KEYCODE_MEDIA_STOP) &&
            playerView.dispatchMediaKeyEvent(event)) {
            playerView.showController()
            return true
        }
        // Give the overlay's focused buttons/slider the event before PlayerView.
        return super.dispatchKeyEvent(event)
    }
    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (::controls.isInitialized) controls.onTouchObserved(event)
        return super.dispatchTouchEvent(event)
    }
}
