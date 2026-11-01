package com.cinemax.cinemax

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.TextView
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView

private class TvActionButton(context: Context) : Button(context) {
    override fun onTouchEvent(event: MotionEvent): Boolean {
        // Take focus on DOWN so UP still clicks once in touch mode. Remote
        // focus remains available when returning from a panel opened by touch.
        if (event.actionMasked == MotionEvent.ACTION_DOWN) requestFocus()
        return super.onTouchEvent(event)
    }
    override fun performClick(): Boolean = super.performClick()
}

/** Native controls: no Flutter frames or full-screen bitmap layers during video. */
@androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
internal class TvPlayerControls(
    private val activity: Activity,
    private val playerView: PlayerView,
    private val changeBrightness: (Int) -> Unit,
    private val openSources: () -> Unit,
) : FrameLayout(activity) {
    // Same primary/surface palette as ciney_core's AppColors.
    private val orange = Color.rgb(255, 107, 0)
    private val rail = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
    private val panel = ScrollView(activity).apply { visibility = GONE; isFillViewport = false }
    private val ui = Handler(Looper.getMainLooper())
    private val autoHide = TvControlsAutoHide(
        { task, delay -> ui.postDelayed(task, delay) }, ui::removeCallbacks, ::hideForInactivity,
    )
    private var player: ExoPlayer? = null
    private var renditions = emptyList<TvVideoRendition>()
    private var chosenHeight: Int? = null
    private var panelKind: String? = null
    private var brightness = 0
    private var pendingBrightness: Runnable? = null
    private var brightnessSupported = true
    private var videoWidth = 0
    private var videoHeight = 0
    private val qualityButton = button("Qualidade", ::showQuality)
    private val brightnessButton = button("Brilho · Original", ::showBrightness)
    private val sourcesButton = button("Servidores", openSources)
    private val listener = object : Player.Listener {
        override fun onTracksChanged(tracks: Tracks) {
            renditions = TvPlaybackOptions.available(tracks.groups.flatMapIndexed { groupIndex, group ->
                if (group.type != C.TRACK_TYPE_VIDEO) emptyList() else
                    (0 until group.length).map { track ->
                        val format = group.getTrackFormat(track)
                        TvVideoRendition(groupIndex, track, format.width, format.height,
                            format.bitrate, group.isTrackSupported(track))
                    }
            })
            applyQuality()
            updateStatus()
            if (panelKind == "quality") showQuality()
        }
        override fun onVideoSizeChanged(videoSize: VideoSize) { updateStatus() }
    }

    init {
        isFocusable = false
        rail.addView(qualityButton)
        rail.addView(brightnessButton)
        rail.addView(sourcesButton)
        addView(rail, LayoutParams(dp(174), LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.END).apply {
            setMargins(dp(16), dp(16), dp(16), 0)
        })
        addView(panel, LayoutParams(dp(310), LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.END).apply {
            setMargins(dp(16), dp(16), dp(16), dp(100))
        })
        playerView.setControllerVisibilityListener(PlayerView.ControllerVisibilityListener { visibility ->
            if (visibility != VISIBLE) {
                panelKind = null
                panel.visibility = GONE
                autoHide.onHidden()
            } else {
                autoHide.onInteraction()
            }
            rail.visibility = if (panelKind == null) visibility else GONE
        })
    }

    fun bind(exo: ExoPlayer?) {
        player?.removeListener(listener)
        player = exo
        exo?.addListener(listener)
        if (exo != null) listener.onTracksChanged(exo.currentTracks)
    }

    fun setBrightness(value: Int) {
        brightness = value.coerceIn(0, 100)
        brightnessButton.text = if (brightness == 0) "Brilho · Original" else "Brilho · +$brightness"
    }

    fun setVideoDimensions(width: Int, height: Int) {
        if (width <= 0 || height <= 0) return
        videoWidth = width
        videoHeight = height
        updateStatus()
    }

    fun disableBrightness() {
        brightnessSupported = false
        setBrightness(0)
        brightnessButton.text = "Brilho indisponível"
        if (panelKind == "brightness") closePanel()
    }

    fun closePanel(): Boolean {
        val previous = panelKind ?: return false
        panelKind = null
        panel.visibility = GONE
        rail.visibility = VISIBLE
        playerView.controllerShowTimeoutMs = TvControlsAutoHide.TIMEOUT_MS
        playerView.showController()
        (if (previous == "quality") qualityButton else brightnessButton).requestFocus()
        autoHide.onInteraction()
        return true
    }

    fun onUserInteraction() {
        autoHide.onInteraction()
        if (panelKind == null && playerView.isControllerFullyVisible) {
            playerView.controllerShowTimeoutMs = TvControlsAutoHide.TIMEOUT_MS
            playerView.showController()
        }
    }

    fun onTouchObserved(event: MotionEvent) {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> autoHide.onTouchStarted()
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> autoHide.onTouchFinished()
        }
    }

    private fun hideForInactivity() {
        val previousPanel = panelKind
        panelKind = null
        panel.visibility = GONE
        panel.clearFocus()
        rail.clearFocus()
        playerView.hideController()
        rail.visibility = GONE
        playerView.requestFocus()
        Log.i("CINEY_NATIVE", "controls=hidden reason=inactivity panel=$previousPanel paused=${player?.playWhenReady == false}")
    }

    fun handleKey(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_BACK && panelKind != null) {
            if (event.action == KeyEvent.ACTION_UP) closePanel()
            return true
        }
        if (panelKind == null && event.keyCode == KeyEvent.KEYCODE_DPAD_UP &&
            !rail.hasFocus()) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                playerView.showController()
                qualityButton.requestFocus()
            }
            return true
        }
        if (panelKind == null && rail.hasFocus() && event.keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
            if (event.action == KeyEvent.ACTION_DOWN) playerView.requestFocus()
            return true
        }
        return false
    }

    fun release() {
        autoHide.release()
        pendingBrightness?.let(ui::removeCallbacks)
        pendingBrightness = null
        bind(null)
    }

    private fun updateStatus() {
        val format = player?.videoFormat
        if (format != null && format.width > 0 && format.height > 0) {
            videoWidth = format.width
            videoHeight = format.height
        }
        val actual = if (videoHeight > 0) "${videoHeight}p" else "Verificando"
        qualityButton.text = "Qualidade · $actual\n${if (chosenHeight == null) "Automática" else "${chosenHeight}p selecionado"}"
        qualityButton.contentDescription = qualityButton.text
    }

    private fun showQuality() {
        val content = newPanel("quality", "Qualidade")
        val dimensions = if (videoWidth > 0 && videoHeight > 0)
            "Em reprodução: $videoWidth × $videoHeight" else "Aguardando informações do vídeo"
        content.addView(text(dimensions))
        val auto = button("${if (chosenHeight == null) "✓ " else ""}Automática") {
            chosenHeight = null
            applyQuality()
            closePanel()
        }
        content.addView(auto)
        var focus: View = auto
        for (option in renditions) {
            val choice = button("${if (chosenHeight == option.height) "✓ " else ""}${option.height}p · ${option.width} × ${option.height}") {
                chosenHeight = option.height
                applyQuality()
                updateStatus()
                closePanel()
            }
            content.addView(choice)
            if (chosenHeight == option.height) focus = choice
        }
        if (renditions.size == 1) content.addView(text("Esta fonte oferece apenas ${renditions.single().height}p."))
        else if (renditions.isEmpty()) content.addView(text("As opções aparecem quando a fonte informa suas faixas."))
        content.addView(button("Outros servidores", openSources))
        content.addView(button("Voltar") { closePanel() })
        focus.requestFocus()
    }

    private fun applyQuality() {
        val exo = player ?: return
        val parameters = exo.trackSelectionParameters
        val builder = parameters.buildUpon().clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .setForceHighestSupportedBitrate(false).setForceLowestBitrate(false)
        val selected = chosenHeight?.let { height -> renditions.firstOrNull { it.height == height } }
        if (selected != null) {
            val group = exo.currentTracks.groups.getOrNull(selected.group)?.mediaTrackGroup ?: return
            builder.setOverrideForType(TrackSelectionOverride(group, listOf(selected.track)))
        }
        // Reapply after a decoder restart; do not reset audio/subtitle settings.
        val updated = builder.build()
        if (updated != parameters) exo.trackSelectionParameters = updated
    }

    private fun showBrightness() {
        if (!brightnessSupported) return
        val content = newPanel("brightness", "Brilho da imagem")
        val value = text(if (brightness == 0) "Original" else "+$brightness")
        content.addView(value)
        val slider = SeekBar(activity).apply {
            isFocusable = true
            isFocusableInTouchMode = true
            max = 100
            progress = brightness
            keyProgressIncrement = 5
            progressTintList = android.content.res.ColorStateList.valueOf(orange)
            thumbTintList = android.content.res.ColorStateList.valueOf(orange)
            contentDescription = "Intensidade do brilho da imagem"
            minimumHeight = dp(56)
            setPadding(dp(12), dp(12), dp(12), dp(12))
        }
        slider.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
                if (!fromUser) return
                setBrightness(progress)
                autoHide.onInteraction()
                value.text = if (progress == 0) "Original" else "+$progress"
                pendingBrightness?.let(ui::removeCallbacks)
                pendingBrightness = Runnable { changeBrightness(progress) }.also { ui.postDelayed(it, 150) }
            }
            override fun onStartTrackingTouch(seekBar: SeekBar) = Unit
            override fun onStopTrackingTouch(seekBar: SeekBar) = Unit
        })
        content.addView(slider)
        content.addView(text("Use as setas para ajustar. O efeito se aplica somente ao filme."))
        content.addView(button("Restaurar original") {
            pendingBrightness?.let(ui::removeCallbacks)
            setBrightness(0)
            changeBrightness(0)
            slider.progress = 0
            value.text = "Original"
        })
        content.addView(button("Voltar") { closePanel() })
        slider.requestFocus()
    }

    private fun newPanel(kind: String, title: String): LinearLayout {
        panelKind = kind
        rail.visibility = GONE
        playerView.controllerShowTimeoutMs = 0
        // The shared deadline closes panels too, including while playback is paused.
        autoHide.onInteraction()
        panel.visibility = VISIBLE
        panel.background = shape(false)
        panel.removeAllViews()
        return LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
            addView(text(title, 20f))
            panel.addView(this)
        }
    }

    private fun text(value: String, size: Float = 14f) = TextView(activity).apply {
        text = value
        textSize = size
        setTextColor(Color.WHITE)
        setPadding(dp(4), dp(8), dp(4), dp(8))
    }

    private fun button(label: String, action: () -> Unit) = TvActionButton(activity).apply {
        isFocusable = true
        isFocusableInTouchMode = true
        text = label
        textSize = 14f
        isAllCaps = false
        gravity = Gravity.CENTER_VERTICAL or Gravity.START
        setTextColor(Color.WHITE)
        setPadding(dp(12), dp(8), dp(12), dp(8))
        minHeight = dp(52)
        layoutParams = LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
            bottomMargin = dp(6)
        }
        background = shape(false)
        setOnFocusChangeListener { _, focused ->
            background = shape(focused)
            if (focused) autoHide.onInteraction()
        }
        setOnClickListener { autoHide.onInteraction(); action() }
    }

    private fun shape(focused: Boolean) = GradientDrawable().apply {
        cornerRadius = dp(12).toFloat()
        setColor(if (focused) Color.rgb(68, 39, 22) else Color.argb(238, 21, 21, 48))
        setStroke(dp(2), if (focused) orange else Color.rgb(52, 52, 72))
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
}
