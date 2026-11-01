package com.example.castlite.casting.roku

import android.content.Context
import android.util.Log
import com.example.castlite.DetectedVideo
import com.example.castlite.LocalMediaProxy
import com.example.castlite.R
import com.example.castlite.casting.CastProtocol
import com.example.castlite.casting.CastTarget
import com.example.castlite.casting.CastTargetListener
import com.example.castlite.casting.PlaybackState
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Timer
import java.util.TimerTask
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicLong
import javax.xml.parsers.DocumentBuilderFactory
import kotlin.concurrent.thread

/**
 * Roku implementation of [CastTarget] using External Control Protocol (ECP).
 * Communicates with the Roku via HTTP REST on port 8060.
 */
class RokuCastTarget(
    private val deviceInfo: RokuDiscovery.RokuDeviceInfo,
    private val appContext: Context
) : CastTarget {

    override val name: String = deviceInfo.friendlyName
    override val protocol = CastProtocol.ROKU

    private val listeners = CopyOnWriteArrayList<CastTargetListener>()
    @Volatile private var _playbackState = PlaybackState.IDLE
    @Volatile private var _positionMs = 0L
    @Volatile private var _durationMs = 0L
    @Volatile private var _connected = false
    private val loadEpoch = AtomicLong()
    private val pollEpoch = AtomicLong()
    private var statusFailures = 0
    override val recoverableIdle: Boolean get() = _playbackState == PlaybackState.ERROR
    private var statusTimer: Timer? = null

    private val baseUrl get() = "http://${deviceInfo.ip}:${deviceInfo.port}"

    override val playbackState: PlaybackState get() = _playbackState
    override val isConnected: Boolean get() = _connected
    override val positionMs: Long get() = _positionMs
    override val durationMs: Long get() = _durationMs
    override val supportsVolumeControl: Boolean get() = true
    override val supportsRemoteNavigation: Boolean get() = true

    override fun connect() {
        _connected = true
        notifyState(PlaybackState.IDLE)
    }

    override fun disconnect() {
        loadEpoch.incrementAndGet()
        stopStatusPolling()
        _connected = false
        notifyState(PlaybackState.IDLE)
    }

    override fun loadMedia(
        video: DetectedVideo,
        mediaProxy: LocalMediaProxy,
        fallbackUserAgent: String,
        onResult: (Boolean) -> Unit
    ) {
        val generation = loadEpoch.incrementAndGet()
        stopStatusPolling()
        _positionMs = 0
        _durationMs = 0
        statusFailures = 0
        _connected = true
        notifyState(PlaybackState.LOADING)

        val mediaUrl = mediaProxy.createMediaUrl(video, fallbackUserAgent) ?: video.url

        thread(name = "Roku-loadMedia", isDaemon = true) {
            try {
                // Launch Roku Media Player (app ID 15985) with the media URL as contentId
                val encodedUrl = URLEncoder.encode(mediaUrl, "UTF-8")
                val encodedType = URLEncoder.encode(rokuMediaType(video.mimeType), "UTF-8")
                val launchUrl = "$baseUrl/launch/$ROKU_MEDIA_PLAYER_ID?contentId=$encodedUrl&mediaType=$encodedType"

                val code = httpPost(launchUrl)
                if (generation != loadEpoch.get()) return@thread
                if (code in 200..299) {
                    Log.d(TAG, "Roku launch success (HTTP $code)")
                    // Launch acceptance is not confirmation that media started.
                    notifyState(PlaybackState.LOADING)
                    startStatusPolling()
                    onResult(true)
                } else {
                    Log.e(TAG, "Roku launch failed (HTTP $code)")
                    notifyState(PlaybackState.ERROR)
                    listeners.forEach { it.onError(appContext.getString(R.string.roku_send_failed)) }
                    onResult(false)
                }
            } catch (e: Exception) {
                if (generation != loadEpoch.get()) return@thread
                Log.w(TAG, "Roku loadMedia error: ${e.javaClass.simpleName}")
                notifyState(PlaybackState.ERROR)
                listeners.forEach { it.onError(appContext.getString(R.string.roku_send_failed)) }
                onResult(false)
            }
        }
    }

    override fun play() {
        sendKeypress("Play") // Play/Pause toggle on Roku
    }

    override fun pause() {
        sendKeypress("Play") // Play/Pause toggle on Roku
    }

    override fun stop() {
        loadEpoch.incrementAndGet()
        stopStatusPolling()
        sendKeypress("Home") // Home exits the player
        _positionMs = 0L
        _durationMs = 0L
        notifyState(PlaybackState.IDLE)
    }

    override fun seek(positionMs: Long) {
        // Roku ECP doesn't support precise seek. Use Fwd/Rev as approximation.
        val diff = positionMs - _positionMs
        if (diff > 0) {
            sendKeypress("Fwd")
        } else if (diff < 0) {
            sendKeypress("Rev")
        }
    }

    override fun adjustVolume(steps: Int): Boolean {
        if (steps == 0) return false
        val command = if (steps > 0) "VolumeUp" else "VolumeDown"
        repeat(kotlin.math.abs(steps).coerceAtMost(5)) { sendKeypress(command) }
        return true
    }

    override fun toggleMute(): Boolean {
        sendKeypress("VolumeMute")
        return true
    }

    override fun sendRemoteKey(key: String): Boolean {
        if (key !in REMOTE_NAVIGATION_KEYS) return false
        sendKeypress(key)
        return true
    }

    override fun addListener(listener: CastTargetListener) {
        listeners.add(listener)
    }

    override fun removeListener(listener: CastTargetListener) {
        listeners.remove(listener)
    }

    // --- ECP commands ---

    private fun sendKeypress(key: String) {
        val generation = loadEpoch.get()
        thread(name = "Roku-key-$key", isDaemon = true) {
            if (generation != loadEpoch.get()) return@thread
            try {
                httpPost("$baseUrl/keypress/$key")
            } catch (e: Exception) {
                Log.w(TAG, "Roku keypress $key failed: ${e.message}")
            }
        }
    }

    private fun httpPost(urlString: String): Int {
        val conn = URL(urlString).openConnection() as HttpURLConnection
        return try {
            conn.requestMethod = "POST"
            conn.connectTimeout = 5_000
            conn.readTimeout = 5_000
            conn.setRequestProperty("Content-Length", "0")
            conn.doOutput = true
            conn.outputStream.close()
            conn.responseCode
        } finally { conn.disconnect() }
    }

    // --- Status polling ---

    private fun startStatusPolling() {
        stopStatusPolling()
        val generation = pollEpoch.get()
        statusTimer = Timer("RokuStatus-${deviceInfo.ip}", true).apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    pollMediaStatus(generation)
                }
            }, 1_000L, POLL_INTERVAL_MS)
        }
    }

    private fun stopStatusPolling() {
        pollEpoch.incrementAndGet()
        statusTimer?.cancel()
        statusTimer = null
    }

    private fun pollMediaStatus(generation: Long) {
        if (generation != pollEpoch.get()) return
        var connection: HttpURLConnection? = null
        try {
            val url = URL("$baseUrl/query/media-player")
            val conn = url.openConnection() as HttpURLConnection
            connection = conn
            conn.connectTimeout = 3_000
            conn.readTimeout = 3_000
            val code = conn.responseCode
            if (code != 200) {
                throw java.io.IOException("Roku status unavailable")
            }
            val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder()
                .parse(conn.inputStream)
            conn.disconnect()
            if (generation != pollEpoch.get()) return
            _connected = true
            statusFailures = 0

            val playerNode = doc.getElementsByTagName("player")?.item(0)
            val stateAttr = playerNode?.attributes?.getNamedItem("state")?.nodeValue
            val positionNode = doc.getElementsByTagName("position")?.item(0)?.textContent
            val durationNode = doc.getElementsByTagName("duration")?.item(0)?.textContent

            val newState = when (stateAttr?.lowercase()) {
                "play" -> PlaybackState.PLAYING
                "pause" -> PlaybackState.PAUSED
                "buffer" -> PlaybackState.BUFFERING
                "close", "stop", "none" -> PlaybackState.IDLE
                else -> _playbackState
            }

            positionNode?.let { _positionMs = parseRokuTime(it) }
            durationNode?.let { _durationMs = parseRokuTime(it) }

            if (newState != _playbackState) notifyState(newState)
            listeners.forEach { it.onPositionChanged(_positionMs, _durationMs) }

            if (newState == PlaybackState.IDLE) stopStatusPolling()
        } catch (_: Exception) {
            if (generation == pollEpoch.get() && ++statusFailures >= 3) {
                _connected = false
                notifyState(PlaybackState.ERROR)
            }
        } finally { connection?.disconnect() }
    }

    private fun notifyState(state: PlaybackState) {
        _playbackState = state
        listeners.forEach { it.onStatusChanged(state) }
    }

    companion object {
        private const val TAG = "RokuCastTarget"
        private const val ROKU_MEDIA_PLAYER_ID = 15985
        private const val POLL_INTERVAL_MS = 1_500L
        private val REMOTE_NAVIGATION_KEYS = setOf("Up", "Down", "Left", "Right", "Select", "Home", "Back", "Info")

        /** Map MIME types to Roku mediaType parameter. */
        fun rokuMediaType(mimeType: String): String = when {
            mimeType.contains("mp4", true) -> "movie"
            mimeType.contains("webm", true) -> "movie"
            mimeType.contains("mpegurl", true) -> "movie"
            mimeType.contains("dash", true) -> "movie"
            else -> "movie"
        }

        /** Parse Roku position/duration format (milliseconds as string). */
        fun parseRokuTime(value: String): Long {
            return try {
                // Roku reports in milliseconds directly
                val cleaned = value.trim().replace(" ms", "")
                cleaned.toLongOrNull() ?: 0L
            } catch (_: Exception) {
                0L
            }
        }
    }
}
