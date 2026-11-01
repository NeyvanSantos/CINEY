package com.example.castlite

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.SeekBar
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import com.example.castlite.casting.CastTarget
import com.example.castlite.casting.CastTargetListener
import com.example.castlite.casting.PlaybackState
import com.example.castlite.databinding.ActivityCastControlBinding
import java.util.Locale

/**
 * Dedicated full-screen remote playback controller.
 * Works with any [CastTarget] (Google Cast, DLNA, Roku).
 * The active target is obtained from [MainActivity.activeTarget].
 */
class RemoteControlActivity : AppCompatActivity() {
    private lateinit var binding: ActivityCastControlBinding
    private var target: CastTarget? = null
    private var durationMs = 0L
    private var userSeeking = false
    private var accessDialogShown = false
    private val sessionListener: (Map<String, Any?>) -> Unit = { state ->
        runOnUiThread {
            if (::binding.isInitialized) {
                binding.controlTitle.text = state["title"] as? String ?: getString(R.string.control_media_unknown)
                val quality = (state["quality"] as? String)?.let { Regex("resolution=(\\d{1,5}x\\d{1,5})").find(it)?.groupValues?.get(1) }
                binding.controlQuality.text = quality?.let { getString(R.string.cast_quality_requested, it) }.orEmpty()
                binding.controlQuality.visibility = if (quality == null) View.GONE else View.VISIBLE
            }
        }
        if (state["error"] == "source_access_denied" && !accessDialogShown) runOnUiThread {
            if (!isFinishing && !isDestroyed) {
                accessDialogShown = true
                val retryRequest = CastingService.sourceRequest()
                androidx.appcompat.app.AlertDialog.Builder(this)
                    .setTitle(R.string.cast_source_denied_title).setMessage(R.string.cast_source_denied_message)
                    .setPositiveButton(R.string.cast_reopen_source) { _, _ ->
                        startActivity(Intent(this, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            putExtra("com.ciney.castlite.REOPEN", true)
                            retryRequest?.let { putExtra(CastRequest.EXTRA, org.json.JSONObject(it.toMap()).toString()) }
                        })
                    }.setNegativeButton(R.string.close, null).show()
            }
        }
        if (state["error"] == "recovery_exhausted") runOnUiThread {
            if (!isFinishing && !isDestroyed) {
                showToast(getString(R.string.cast_recovery_exhausted))
                finish()
            }
        }
    }

    private val targetListener = object : CastTargetListener {
        override fun onStatusChanged(state: PlaybackState) = runOnUiThread { refreshControls() }
        override fun onPositionChanged(positionMs: Long, durationMs: Long) {
            runOnUiThread {
                if (!isFinishing && !isDestroyed) updateTimeline(positionMs, durationMs)
            }
        }
        override fun onError(message: String) = runOnUiThread { showToast(message) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityCastControlBinding.inflate(layoutInflater)
        setContentView(binding.root)
        setSupportActionBar(binding.controlToolbar)
        binding.controlToolbar.setNavigationOnClickListener { finish() }
        binding.backToBrowser.setOnClickListener { finish() }
        binding.controlPlayPause.setOnClickListener { togglePlayback() }
        binding.controlSeekBack.setOnClickListener { seekRelative(-SKIP_INTERVAL_MS) }
        binding.controlSeekForward.setOnClickListener { seekRelative(SKIP_INTERVAL_MS) }
        binding.controlStop.setOnClickListener { stopPlayback() }
        binding.controlVolumeDown.setOnClickListener { adjustVolume(-1) }
        binding.controlVolumeUp.setOnClickListener { adjustVolume(1) }
        binding.controlMute.setOnClickListener { toggleMute() }
        binding.remoteUp.setOnClickListener { sendRemoteKey("Up") }
        binding.remoteDown.setOnClickListener { sendRemoteKey("Down") }
        binding.remoteLeft.setOnClickListener { sendRemoteKey("Left") }
        binding.remoteRight.setOnClickListener { sendRemoteKey("Right") }
        binding.remoteSelect.setOnClickListener { sendRemoteKey("Select") }
        binding.remoteHome.setOnClickListener { sendRemoteKey("Home") }
        binding.remoteBack.setOnClickListener { sendRemoteKey("Back") }
        binding.remoteInfo.setOnClickListener { sendRemoteKey("Info") }
        configureSeekBar()

        WindowCompat.setDecorFitsSystemWindows(window, false)
        ViewCompat.setOnApplyWindowInsetsListener(binding.controlRoot) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }
    }

    override fun onStart() {
        super.onStart()
        // Get active target from the owning MainActivity instance
        target = CastingService.target ?: lastMainActivity?.activeTarget
        target?.addListener(targetListener)
        CastSessionEvents.addListener(sessionListener)
        sessionListener(CastSessionEvents.snapshot())
        refreshControls()
    }

    override fun onStop() {
        CastSessionEvents.removeListener(sessionListener)
        target?.removeListener(targetListener)
        target = null
        super.onStop()
    }

    private fun refreshControls() {
        if (!::binding.isInitialized) return
        val t = target
        val state = t?.playbackState ?: PlaybackState.IDLE
        val connected = t?.isConnected == true

        binding.controlDevice.text = t?.name?.let { getString(R.string.cast_connected, it) }
            ?: getString(R.string.control_device_unknown)

        binding.controlTitle.text = CastSessionEvents.snapshot()["title"] as? String ?: getString(R.string.control_media_unknown)

        binding.controlStatus.text = when {
            !connected -> getString(R.string.control_disconnected)
            state == PlaybackState.PLAYING -> getString(R.string.control_playing)
            state == PlaybackState.BUFFERING -> getString(R.string.control_buffering)
            state == PlaybackState.PAUSED -> getString(R.string.control_paused)
            state == PlaybackState.LOADING -> getString(R.string.control_waiting_media)
            state == PlaybackState.IDLE -> getString(R.string.control_idle)
            else -> getString(R.string.control_waiting)
        }
        binding.controlBuffering.visibility = if (state == PlaybackState.BUFFERING) View.VISIBLE else View.GONE
        binding.controlPlayPause.setText(if (state == PlaybackState.PLAYING) R.string.pause else R.string.play)

        val active = connected && !CastingService.needsSourceAction() && state !in listOf(PlaybackState.IDLE, PlaybackState.ERROR)
        binding.controlPlayPause.isEnabled = active
        binding.controlSeekBack.isEnabled = active
        binding.controlSeekForward.isEnabled = active
        binding.controlStop.isEnabled = connected

        val canAdjustVolume = connected && t?.supportsVolumeControl == true
        binding.controlVolumeDown.isEnabled = canAdjustVolume
        binding.controlVolumeUp.isEnabled = canAdjustVolume
        binding.controlMute.isEnabled = canAdjustVolume
        val canNavigate = connected && t?.supportsRemoteNavigation == true
        listOf(binding.remoteUp, binding.remoteDown, binding.remoteLeft, binding.remoteRight,
            binding.remoteSelect, binding.remoteHome, binding.remoteBack, binding.remoteInfo)
            .forEach { it.isEnabled = canNavigate }
        binding.remoteCapabilityHint.setText(
            if (canNavigate) R.string.remote_capabilities_available else R.string.remote_capabilities_limited
        )

        val dur = t?.durationMs ?: 0L
        if (dur > 0L) durationMs = dur
        binding.totalTime.text = formatTime(durationMs)
        binding.mediaSeekBar.isEnabled = active && durationMs > 0L
        if (!userSeeking && durationMs > 0L) {
            updateTimeline(t?.positionMs ?: 0L, durationMs)
        }
    }

    private fun configureSeekBar() {
        binding.mediaSeekBar.max = SEEK_SCALE
        binding.mediaSeekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onStartTrackingTouch(seekBar: SeekBar) {
                userSeeking = true
            }

            override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
                if (fromUser && durationMs > 0L) {
                    binding.currentTime.text = formatTime(durationMs * progress / SEEK_SCALE)
                }
            }

            override fun onStopTrackingTouch(seekBar: SeekBar) {
                userSeeking = false
                val duration = durationMs
                if (duration <= 0L) return
                val position = duration * seekBar.progress / SEEK_SCALE
                if (target === CastingService.target) CastingService.seekTo(position) else target?.seek(position)
            }
        })
    }

    private fun seekRelative(offsetMs: Long) {
        val t = target ?: return
        val position = t.positionMs.coerceAtLeast(0L)
        val duration = maxOf(durationMs, t.durationMs)
        val dest = (position + offsetMs).coerceAtLeast(0L).let { if (duration > 0L) minOf(it, duration) else it }
        if (t === CastingService.target) CastingService.seekTo(dest) else t.seek(dest)
    }

    private fun updateTimeline(position: Long, duration: Long) {
        if (!::binding.isInitialized) return
        if (duration > 0L) durationMs = duration
        binding.totalTime.text = formatTime(durationMs)
        if (!userSeeking && durationMs > 0L) {
            binding.mediaSeekBar.progress = ((position.coerceAtLeast(0L).toDouble() / durationMs) * SEEK_SCALE)
                .toInt().coerceIn(0, SEEK_SCALE)
            binding.currentTime.text = formatTime(position)
        }
    }

    private fun togglePlayback() {
        val t = target ?: return
        val pause = t.playbackState == PlaybackState.PLAYING
        CastingService.setUserPaused(pause)
        if (pause) t.pause() else t.play()
    }

    private fun stopPlayback() {
        val t = target ?: run { finish(); return }
        binding.controlStop.isEnabled = false
        t.stop()
        if (t === CastingService.target) stopService(Intent(this, CastingService::class.java))
        showToast(getString(R.string.control_stop_confirmed))
        finish()
    }

    private fun adjustVolume(steps: Int) {
        if (target?.adjustVolume(steps) != true) showToast(getString(R.string.control_volume_error))
    }

    private fun toggleMute() {
        if (target?.toggleMute() != true) showToast(getString(R.string.control_volume_error))
    }

    private fun sendRemoteKey(key: String) {
        if (target?.sendRemoteKey(key) != true) showToast(getString(R.string.control_remote_key_error))
    }

    private fun showToast(message: String) = Toast.makeText(this, message, Toast.LENGTH_LONG).show()

    private fun formatTime(milliseconds: Long): String {
        val seconds = milliseconds.coerceAtLeast(0L) / 1_000L
        val hours = seconds / 3_600L
        val minutes = (seconds % 3_600L) / 60L
        val remainder = seconds % 60L
        return if (hours > 0) String.format(Locale.getDefault(), "%d:%02d:%02d", hours, minutes, remainder)
        else String.format(Locale.getDefault(), "%02d:%02d", seconds / 60L, remainder)
    }

    companion object {
        private const val SEEK_SCALE = 1_000
        private const val SKIP_INTERVAL_MS = 10_000L

        // Simple reference to the last created MainActivity for obtaining the active target.
        // A proper DI framework (Hilt) would be better, but this keeps the MVP simple.
        private var lastActivity = java.lang.ref.WeakReference<MainActivity>(null)
        internal var lastMainActivity: MainActivity?
            get() = lastActivity.get()
            set(value) { lastActivity = java.lang.ref.WeakReference(value) }

        fun launch(from: Activity) {
            if (from is MainActivity) lastMainActivity = from
            from.startActivity(Intent(from, RemoteControlActivity::class.java))
        }
    }
}
