package com.example.castlite.casting.dlna

import android.content.Context
import android.util.Log
import com.example.castlite.DetectedVideo
import com.example.castlite.LocalMediaProxy
import com.example.castlite.R
import com.example.castlite.casting.CastProtocol
import com.example.castlite.casting.CastTarget
import com.example.castlite.casting.CastTargetListener
import com.example.castlite.casting.PlaybackState
import org.jupnp.controlpoint.ControlPoint
import org.jupnp.model.action.ActionInvocation
import org.jupnp.model.message.UpnpResponse
import org.jupnp.model.meta.RemoteDevice
import org.jupnp.model.types.ServiceType
import org.jupnp.support.avtransport.callback.GetPositionInfo
import org.jupnp.support.avtransport.callback.GetTransportInfo
import org.jupnp.support.model.TransportInfo
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import org.jupnp.support.avtransport.callback.Pause
import org.jupnp.support.avtransport.callback.Play
import org.jupnp.support.avtransport.callback.Seek
import org.jupnp.support.avtransport.callback.SetAVTransportURI
import org.jupnp.support.avtransport.callback.Stop
import org.jupnp.support.renderingcontrol.callback.GetMute
import org.jupnp.support.renderingcontrol.callback.GetVolume
import org.jupnp.support.renderingcontrol.callback.SetMute
import org.jupnp.support.renderingcontrol.callback.SetVolume
import org.jupnp.support.model.PositionInfo
import java.util.Locale
import java.util.Timer
import java.util.TimerTask
import java.util.concurrent.CopyOnWriteArrayList

/**
 * DLNA implementation of [CastTarget].
 * Uses AVTransport service to control a Media Renderer via jUPnP.
 */
class DlnaCastTarget(
    private val device: RemoteDevice,
    private var controlPoint: ControlPoint?,
    private val appContext: Context
) : CastTarget {

    override val name: String = device.details.friendlyName ?: device.displayString
    override val protocol = CastProtocol.DLNA

    val deviceUdn: String = device.identity.udn.identifierString

    private val listeners = CopyOnWriteArrayList<CastTargetListener>()
    @Volatile private var _playbackState = PlaybackState.IDLE
    @Volatile private var _positionMs = 0L
    @Volatile private var _durationMs = 0L
    @Volatile private var _connected = false
    private val pollEpoch = AtomicLong()
    private val transportPending = AtomicBoolean(false)
    private val positionPending = AtomicBoolean(false)
    private val loadEpoch = AtomicLong()
    @Volatile private var transportSupported = true
    override val reportsTransportState: Boolean get() = transportSupported
    private var transportFailures = 0
    override val recoverableIdle: Boolean get() = _playbackState == PlaybackState.ERROR
    private var positionTimer: Timer? = null

    private val avTransportService
        get() = device.findService(ServiceType("schemas-upnp-org", "AVTransport"))

    private val renderingControlService
        get() = device.findService(ServiceType("schemas-upnp-org", "RenderingControl"))

    override val playbackState: PlaybackState get() = _playbackState
    override val isConnected: Boolean get() = _connected
    override val positionMs: Long get() = _positionMs
    override val durationMs: Long get() = _durationMs
    override val supportsVolumeControl: Boolean get() = renderingControlService != null

    override fun connect() {
        _connected = true
        startPositionPolling()
        notifyState(PlaybackState.IDLE)
    }

    override fun disconnect() {
        loadEpoch.incrementAndGet()
        stopPositionPolling()
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
        _positionMs = 0
        _durationMs = 0
        transportFailures = 0
        val service = avTransportService
        val cp = controlPoint
        if (service == null || cp == null) {
            onResult(false)
            return
        }

        _connected = true
        notifyState(PlaybackState.LOADING)

        val mediaUrl = mediaProxy.createMediaUrl(video, fallbackUserAgent) ?: video.url
        val metadata = DidlLiteBuilder.buildVideoItem(video.title, mediaUrl, video.mimeType)

        val setUriCallback = object : SetAVTransportURI(service, mediaUrl, metadata) {
            override fun success(invocation: ActionInvocation<*>?) {
                if (generation != loadEpoch.get()) return
                Log.d(TAG, "SetAVTransportURI success, triggering Play")
                // URI set, now play
                val playCallback = object : Play(service) {
                    override fun success(invocation: ActionInvocation<*>?) {
                        if (generation != loadEpoch.get()) return
                        Log.d(TAG, "DLNA Play accepted")
                        // The command was accepted; polling confirms actual playback.
                        notifyState(PlaybackState.LOADING)
                        startPositionPolling()
                        onResult(true)
                    }

                    override fun failure(
                        invocation: ActionInvocation<*>,
                        operation: UpnpResponse?,
                        defaultMsg: String?
                    ) {
                        if (generation != loadEpoch.get()) return
                        Log.w(TAG, "DLNA Play failed code=${invocation.failure?.errorCode}")
                        notifyState(PlaybackState.ERROR)
                        listeners.forEach { it.onError(appContext.getString(R.string.dlna_send_failed)) }
                        onResult(false)
                    }
                }
                cp.execute(playCallback)
            }

            override fun failure(
                invocation: ActionInvocation<*>,
                operation: UpnpResponse?,
                defaultMsg: String?
            ) {
                if (generation != loadEpoch.get()) return
                Log.w(TAG, "SetAVTransportURI failed code=${invocation.failure?.errorCode}")
                notifyState(PlaybackState.ERROR)
                listeners.forEach { it.onError(appContext.getString(R.string.dlna_send_failed)) }
                onResult(false)
            }
        }
        cp.execute(setUriCallback)
    }

    override fun play() {
        val generation = loadEpoch.get()
        val service = avTransportService ?: return
        val cp = controlPoint ?: return
        cp.execute(object : Play(service) {
            override fun success(invocation: ActionInvocation<*>?) {
                if (generation != loadEpoch.get()) return
                notifyState(PlaybackState.PLAYING)
            }

            override fun failure(invocation: ActionInvocation<*>, operation: UpnpResponse?, defaultMsg: String?) {
                listeners.forEach { it.onError(appContext.getString(R.string.cast_command_error)) }
            }
        })
    }

    override fun pause() {
        val generation = loadEpoch.get()
        val service = avTransportService ?: return
        val cp = controlPoint ?: return
        cp.execute(object : Pause(service) {
            override fun success(invocation: ActionInvocation<*>?) {
                if (generation != loadEpoch.get()) return
                notifyState(PlaybackState.PAUSED)
            }

            override fun failure(invocation: ActionInvocation<*>, operation: UpnpResponse?, defaultMsg: String?) {
                listeners.forEach { it.onError(appContext.getString(R.string.cast_command_error)) }
            }
        })
    }

    override fun stop() {
        val generation = loadEpoch.incrementAndGet()
        val service = avTransportService ?: return
        val cp = controlPoint ?: return
        stopPositionPolling()
        cp.execute(object : Stop(service) {
            override fun success(invocation: ActionInvocation<*>?) {
                if (generation != loadEpoch.get()) return
                _positionMs = 0L
                _durationMs = 0L
                notifyState(PlaybackState.IDLE)
            }

            override fun failure(invocation: ActionInvocation<*>, operation: UpnpResponse?, defaultMsg: String?) {
                listeners.forEach { it.onError(appContext.getString(R.string.cast_command_error)) }
            }
        })
    }

    override fun seek(positionMs: Long) {
        val generation = loadEpoch.get()
        val service = avTransportService ?: return
        val cp = controlPoint ?: return
        val target = formatTime(positionMs)
        cp.execute(object : Seek(service, target) {
            override fun success(invocation: ActionInvocation<*>?) {
                if (generation != loadEpoch.get()) return
                _positionMs = positionMs
                listeners.forEach { it.onPositionChanged(positionMs, _durationMs) }
            }

            override fun failure(invocation: ActionInvocation<*>, operation: UpnpResponse?, defaultMsg: String?) {
                listeners.forEach { it.onError(appContext.getString(R.string.control_seek_failed)) }
            }
        })
    }

    override fun adjustVolume(steps: Int): Boolean {
        if (steps == 0) return false
        val service = renderingControlService ?: return false
        val cp = controlPoint ?: return false
        val delta = if (steps > 0) VOLUME_STEP else -VOLUME_STEP
        cp.execute(object : GetVolume(service) {
            override fun received(invocation: ActionInvocation<*>, volume: Int) {
                val nextVolume = (volume + delta).coerceIn(0, MAX_VOLUME).toLong()
                cp.execute(object : SetVolume(service, nextVolume) {
                    override fun failure(invocation: ActionInvocation<*>, operation: UpnpResponse?, defaultMsg: String?) {
                        notifyCommandError()
                    }
                })
            }

            override fun failure(invocation: ActionInvocation<*>, operation: UpnpResponse?, defaultMsg: String?) {
                notifyCommandError()
            }
        })
        return true
    }

    override fun toggleMute(): Boolean {
        val service = renderingControlService ?: return false
        val cp = controlPoint ?: return false
        cp.execute(object : GetMute(service) {
            override fun received(invocation: ActionInvocation<*>, mute: Boolean) {
                cp.execute(object : SetMute(service, !mute) {
                    override fun failure(invocation: ActionInvocation<*>, operation: UpnpResponse?, defaultMsg: String?) {
                        notifyCommandError()
                    }
                })
            }

            override fun failure(invocation: ActionInvocation<*>, operation: UpnpResponse?, defaultMsg: String?) {
                notifyCommandError()
            }
        })
        return true
    }

    override fun addListener(listener: CastTargetListener) {
        listeners.add(listener)
    }

    override fun removeListener(listener: CastTargetListener) {
        listeners.remove(listener)
    }

    // --- Position polling ---

    private fun startPositionPolling() {
        stopPositionPolling()
        val epoch = pollEpoch.get()
        positionTimer = Timer("DlnaPosition-${deviceUdn.take(8)}", true).apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    pollPosition(epoch)
                }
            }, 0L, POLL_INTERVAL_MS)
        }
    }

    private fun stopPositionPolling() {
        pollEpoch.incrementAndGet()
        transportPending.set(false)
        positionPending.set(false)
        positionTimer?.cancel()
        positionTimer = null
    }

    private fun pollPosition(epoch: Long) {
        if (epoch != pollEpoch.get()) return
        val service = avTransportService ?: return
        val cp = controlPoint ?: return
        if (transportSupported && transportPending.compareAndSet(false, true)) cp.execute(object : GetTransportInfo(service) {
            override fun received(invocation: ActionInvocation<*>, info: TransportInfo) {
                if (epoch != pollEpoch.get()) return
                transportPending.set(false)
                transportFailures = 0
                _connected = true
                val state = if (info.currentTransportStatus.toString() == "ERROR_OCCURRED") PlaybackState.ERROR
                    else transportPlaybackState(info.currentTransportState.toString())
                if (state != null && state != _playbackState) notifyState(state)
            }
            override fun failure(invocation: ActionInvocation<*>, operation: UpnpResponse?, defaultMsg: String?) {
                if (epoch != pollEpoch.get()) return
                transportPending.set(false)
                if (invocation.failure?.errorCode == 401) {
                    transportSupported = false
                    Log.w(TAG, "Renderer does not expose transport state")
                    listeners.forEach { it.onError(appContext.getString(R.string.cast_limited_transport_state)) }
                } else if (++transportFailures >= 3) {
                    _connected = false
                    notifyState(PlaybackState.ERROR)
                }
            }
        })
        if (!positionPending.compareAndSet(false, true)) return
        cp.execute(object : GetPositionInfo(service) {
            override fun received(invocation: ActionInvocation<*>, positionInfo: PositionInfo) {
                if (epoch != pollEpoch.get()) return
                positionPending.set(false)
                val trackDuration = parseTime(positionInfo.trackDuration)
                val relTime = parseTime(positionInfo.relTime)
                if (trackDuration > 0L) _durationMs = trackDuration
                if (!transportSupported && relTime > _positionMs &&
                    _playbackState in listOf(PlaybackState.LOADING, PlaybackState.BUFFERING)) {
                    notifyState(PlaybackState.PLAYING)
                }
                _positionMs = relTime
                listeners.forEach { it.onPositionChanged(relTime, _durationMs) }
            }

            override fun failure(invocation: ActionInvocation<*>, operation: UpnpResponse?, defaultMsg: String?) {
                if (epoch != pollEpoch.get()) return
                positionPending.set(false)
                // Some renderers may not support position queries; ignore silently
            }
        })
    }

    private fun notifyState(state: PlaybackState) {
        _playbackState = state
        listeners.forEach { it.onStatusChanged(state) }
    }

    private fun notifyCommandError() {
        listeners.forEach { it.onError(appContext.getString(R.string.cast_command_error)) }
    }

    companion object {
        fun transportPlaybackState(value: String): PlaybackState? = when (value) {
            "PLAYING" -> PlaybackState.PLAYING
            "PAUSED_PLAYBACK", "PAUSED_RECORDING" -> PlaybackState.PAUSED
            "STOPPED", "NO_MEDIA_PRESENT" -> PlaybackState.IDLE
            "TRANSITIONING" -> PlaybackState.BUFFERING
            else -> null
        }
        private const val TAG = "DlnaCastTarget"
        private const val POLL_INTERVAL_MS = 1_000L
        private const val VOLUME_STEP = 5
        private const val MAX_VOLUME = 100

        /** Format milliseconds as HH:MM:SS for DLNA Seek. */
        fun formatTime(ms: Long): String {
            val totalSeconds = ms.coerceAtLeast(0L) / 1_000L
            val hours = totalSeconds / 3_600L
            val minutes = (totalSeconds % 3_600L) / 60L
            val seconds = totalSeconds % 60L
            return String.format(Locale.ROOT, "%02d:%02d:%02d", hours, minutes, seconds)
        }

        /** Parse HH:MM:SS or H:MM:SS to milliseconds. Returns 0 on failure. */
        fun parseTime(timeString: String?): Long {
            if (timeString.isNullOrBlank() || timeString == "NOT_IMPLEMENTED") return 0L
            return try {
                val parts = timeString.split(":")
                when (parts.size) {
                    3 -> {
                        val h = parts[0].toLong()
                        val m = parts[1].toLong()
                        val s = parts[2].substringBefore('.').toLong()
                        (h * 3600 + m * 60 + s) * 1000L
                    }
                    2 -> {
                        val m = parts[0].toLong()
                        val s = parts[1].substringBefore('.').toLong()
                        (m * 60 + s) * 1000L
                    }
                    else -> 0L
                }
            } catch (_: Exception) {
                0L
            }
        }
    }
}
