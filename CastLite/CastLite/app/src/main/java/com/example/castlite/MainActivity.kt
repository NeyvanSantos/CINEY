package com.example.castlite

import android.annotation.SuppressLint
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.text.TextUtils
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.mediarouter.media.MediaRouter
import com.example.castlite.casting.CastProtocol
import com.example.castlite.casting.CastTarget
import com.example.castlite.casting.CastTargetListener
import com.example.castlite.casting.DeviceDiscovery
import com.example.castlite.casting.PlaybackState
import com.example.castlite.casting.dlna.DlnaDiscovery
import com.example.castlite.casting.google.GoogleCastTarget
import com.example.castlite.casting.roku.RokuDiscovery
import com.example.castlite.databinding.ActivityMainBinding
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import org.json.JSONArray

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private lateinit var mediaProxy: LocalMediaProxy

    // --- Unified casting ---
    val deviceDiscovery = DeviceDiscovery()
    var activeTarget: CastTarget? = null
        private set

    // --- Google Cast discovery and session ---
    private var castContext: CastContext? = null
    private var castUnavailable = false
    private var castLoadRequestId = 0
    private var mediaRouter: MediaRouter? = null
    private var castRouteDiscoveryRegistered = false
    private var pickerDialog: AlertDialog? = null
    private var waitingForGoogleCastRoutes = false
    private var pickerPendingVideo: DetectedVideo? = null
    private var pendingVideoForGoogleCast: DetectedVideo? = null

    private data class DevicePickerEntry(
        val label: String,
        val target: CastTarget? = null,
        val route: MediaRouter.RouteInfo? = null
    )

    // --- DLNA / Roku discovery ---
    private var dlnaDiscovery: DlnaDiscovery? = null
    private var rokuDiscovery: RokuDiscovery? = null

    // --- Video detection ---
    private val videos = VideoCatalog()
    private var currentPageUrl = ""
    private var frameMediaObserver: FrameMediaObserver? = null
    private val mediaRequestHeaders = LinkedHashMap<String, Map<String, String>>()

    // --- Lifecycle flags ---
    private var started = false
    private var listening = false

    // --- CiNey Bridge & Auto-Cast ---
    private var autoCastOnDetect = false
    private var incomingTitle: String? = null
    private var incomingResumePositionMs: Long = 0L
    private var isIncomingEmbed = false
    private var incomingTargetHost: String? = null
    private var incomingRequest: CastRequest? = null

    private val sessionListener = SimpleSessionListener(
        onChange = { runOnUiThread { onCastSessionChanged() } },
        onError = { code -> runOnUiThread { toast(getString(R.string.cast_connection_error, code)) } }
    )

    private val castRouteCallback = object : MediaRouter.Callback() {
        override fun onRouteAdded(router: MediaRouter, route: MediaRouter.RouteInfo) = onCastRoutesChanged(router)
        override fun onRouteChanged(router: MediaRouter, route: MediaRouter.RouteInfo) = onCastRoutesChanged(router)
        override fun onRouteRemoved(router: MediaRouter, route: MediaRouter.RouteInfo) = onCastRoutesChanged(router)
        override fun onRouteSelected(router: MediaRouter, route: MediaRouter.RouteInfo) = onCastRoutesChanged(router)
        override fun onRouteUnselected(router: MediaRouter, route: MediaRouter.RouteInfo) = onCastRoutesChanged(router)
    }

    private val targetListener = object : CastTargetListener {
        override fun onStatusChanged(state: PlaybackState) = runOnUiThread {
            updateControlBar()
            CastSessionEvents.update(activeTarget)
        }
        override fun onPositionChanged(positionMs: Long, durationMs: Long) {}
        override fun onError(message: String) = runOnUiThread { toast(message) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        mediaProxy = LocalMediaProxy(applicationContext)
        setContentView(binding.root)
        setSupportActionBar(binding.toolbar)
        // targetSdk 35: respeita barras do sistema, recorte da tela e teclado.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            val keyboard = insets.getInsets(WindowInsetsCompat.Type.ime())
            view.setPadding(bars.left, bars.top, bars.right, maxOf(bars.bottom, keyboard.bottom))
            insets
        }
        setupUi()
        setupWebView()
        CastingService.target?.let { setActiveTarget(it) }
        initializeCast()
        initializeDlna()
        initializeRoku()
        // Android 13+: controles de mídia na notificação exigem permissão em runtime.
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 42)
        }
        val handled = handleIncomingIntent(intent)
        if (!handled) {
            if (savedInstanceState == null || binding.webView.restoreState(savedInstanceState) == null) {
                binding.webView.loadUrl(HOME_URL)
            } else {
                currentPageUrl = binding.webView.url.orEmpty()
                binding.urlInput.setText(currentPageUrl)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    // ───────────────────────── Google Cast bootstrap ─────────────────────────

    private fun initializeCast() {
        if (!GoogleCastTarget.isAvailable(this)) {
            disableCast()
            return
        }
        GoogleCastTarget.initializeCastContext(
            this,
            onSuccess = { context ->
                if (!isDestroyed && !isFinishing) {
                    castContext = context
                    attachCastListeners()
                    attachCastRouteDiscovery()
                    invalidateOptionsMenu()
                    onCastSessionChanged()
                }
            },
            onFailure = { if (!isDestroyed) disableCast() }
        )
    }

    private fun disableCast() {
        detachCastListeners()
        detachCastRouteDiscovery()
        castContext = null
        castUnavailable = true
        invalidateOptionsMenu()
        updateStatusText()
    }

    /** Descobre as rotas Google Cast para o seletor unificado de TVs. */
    private fun attachCastRouteDiscovery() {
        val context = castContext ?: return
        try {
            val router = MediaRouter.getInstance(applicationContext)
            mediaRouter = router
            val selector = context.mergedSelector ?: return
            if (!castRouteDiscoveryRegistered) {
                router.addCallback(
                    selector,
                    castRouteCallback,
                    MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY
                )
                castRouteDiscoveryRegistered = true
            }
            onCastRoutesChanged(router)
        } catch (error: Exception) {
            android.util.Log.w("CastLite", "Google Cast route discovery failed: ${error.javaClass.simpleName}")
        }
    }

    private fun detachCastRouteDiscovery() {
        if (!castRouteDiscoveryRegistered) return
        try { mediaRouter?.removeCallback(castRouteCallback) } catch (_: Exception) {}
        castRouteDiscoveryRegistered = false
    }

    private fun googleCastRoutes(router: MediaRouter? = mediaRouter): List<MediaRouter.RouteInfo> {
        val activeRouter = router ?: return emptyList()
        val selector = runCatching { castContext?.mergedSelector }.getOrNull() ?: return emptyList()
        return activeRouter.routes
            .filter { it.isEnabled && !it.isDefault && it.matchesSelector(selector) }
            .distinctBy { it.id }
    }

    private fun onCastRoutesChanged(router: MediaRouter) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            runOnUiThread { onCastRoutesChanged(router) }
            return
        }
        if (isDestroyed || isFinishing || !waitingForGoogleCastRoutes || googleCastRoutes(router).isEmpty()) return
        val pendingVideo = pickerPendingVideo
        waitingForGoogleCastRoutes = false
        pickerDialog?.dismiss()
        pickerDialog = null
        showDevicePickerDialog(pendingVideo)
    }

    // ───────────────────────── DLNA bootstrap ─────────────────────────

    private fun initializeDlna() {
        try {
            dlnaDiscovery = DlnaDiscovery(applicationContext, deviceDiscovery).also { it.start() }
        } catch (e: Exception) {
            android.util.Log.w("CastLite", "DLNA init failed: ${e.message}")
        }
    }

    // ───────────────────────── Roku bootstrap ─────────────────────────

    private fun initializeRoku() {
        try {
            rokuDiscovery = RokuDiscovery(applicationContext, deviceDiscovery).also { it.start() }
        } catch (e: Exception) {
            android.util.Log.w("CastLite", "Roku init failed: ${e.message}")
        }
    }

    private fun onCastSessionChanged() {
        val session = castContext?.sessionManager?.currentCastSession?.takeIf { it.isConnected }
        if (session != null) {
            val target = (CastingService.target as? GoogleCastTarget)?.takeIf { it.matchesSession(session) }
                ?: (activeTarget as? GoogleCastTarget)?.takeIf { it.matchesSession(session) }
                ?: GoogleCastTarget.fromSession(session, applicationContext)
            if (target != null) {
                if (activeTarget !== target) setActiveTarget(target)
                if (started) {
                    pendingVideoForGoogleCast?.let { video ->
                        pendingVideoForGoogleCast = null
                        castVideo(video)
                    }
                }
            }
        } else if (activeTarget?.protocol == CastProtocol.GOOGLE_CAST) {
            setActiveTarget(null)
        }
        updateStatusText()
        updateControlBar()
    }

    /** Set the active casting target (any protocol). */
    fun setActiveTarget(target: CastTarget?) {
        activeTarget?.removeListener(targetListener)
        if (activeTarget !== CastingService.target) (activeTarget as? GoogleCastTarget)?.detachClient()
        activeTarget = target
        target?.addListener(targetListener)
        (target as? GoogleCastTarget)?.attachClient()
        updateStatusText()
        updateControlBar()
    }

    // ───────────────────────── Menu / Toolbar ─────────────────────────

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.main_menu, menu)
        menu.findItem(R.id.action_economy).isChecked = mediaProxy.economyMode
        menu.findItem(R.id.action_servers).isVisible = (incomingRequest?.sources?.size ?: 0) > 1
        return true
    }

    override fun onPrepareOptionsMenu(menu: Menu): Boolean {
        menu.findItem(R.id.action_back)?.isEnabled = binding.webView.canGoBack()
        return super.onPrepareOptionsMenu(menu)
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean = when (item.itemId) {
        android.R.id.home -> { finish(); true }
        R.id.action_servers -> {
            incomingRequest?.let { request ->
                AlertDialog.Builder(this).setTitle(R.string.cast_choose_server)
                    .setSingleChoiceItems(request.sources.map { it.server }.toTypedArray(), request.sourceIndex) { dialog, index ->
                        dialog.dismiss()
                        openInternalRequest(request.copy(sourceIndex = index,
                            positionMs = activeTarget?.positionMs ?: request.positionMs))
                    }.setNegativeButton(R.string.close, null).show()
            }
            true
        }
        R.id.action_economy -> {
            mediaProxy.economyMode = !mediaProxy.economyMode
            item.isChecked = mediaProxy.economyMode
            getSharedPreferences("casting", MODE_PRIVATE).edit().putBoolean("economy", mediaProxy.economyMode).apply()
            toast("Qualidade alterada para a próxima transmissão")
            true
        }
        R.id.action_back -> { if (binding.webView.canGoBack()) binding.webView.goBack(); true }
        R.id.action_reload -> { binding.webView.reload(); true }
        else -> super.onOptionsItemSelected(item)
    }

    // ───────────────────────── Lifecycle ─────────────────────────

    override fun onStart() {
        super.onStart()
        started = true
        attachCastListeners()
        attachCastRouteDiscovery()
        onCastSessionChanged()
    }

    private fun attachCastListeners() {
        if (started && !listening && castContext != null) {
            castContext?.sessionManager?.addSessionManagerListener(sessionListener, CastSession::class.java)
            listening = true
        }
    }

    private fun detachCastListeners() {
        if (listening) castContext?.sessionManager?.removeSessionManagerListener(sessionListener, CastSession::class.java)
        listening = false
    }

    override fun onStop() {
        started = false
        detachCastListeners()
        detachCastRouteDiscovery()
        super.onStop()
    }

    override fun onResume() {
        super.onResume()
        binding.webView.onResume()
    }

    override fun onPause() {
        if (!CastingService.owns(mediaProxy)) binding.webView.onPause()
        super.onPause()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        binding.webView.saveState(outState)
        super.onSaveInstanceState(outState)
    }

    override fun onDestroy() {
        detachCastListeners()
        detachCastRouteDiscovery()
        activeTarget?.removeListener(targetListener)
        if (RemoteControlActivity.lastMainActivity === this) RemoteControlActivity.lastMainActivity = null
        (binding.webView.parent as? ViewGroup)?.removeView(binding.webView)
        // O serviço mantém o navegador de origem e o relay até o fim da sessão.
        CastingService.retainCleanup(mediaProxy) {
            frameMediaObserver?.close()
            mediaRequestHeaders.clear()
            dlnaDiscovery?.stop()
            rokuDiscovery?.stop()
            (activeTarget as? GoogleCastTarget)?.detachClient()
            mediaProxy.close()
            videos.beginPage()
            binding.webView.stopLoading()
            binding.webView.destroy()
        }
        super.onDestroy()
    }

    // ───────────────────────── Unified UI updates ─────────────────────────

    private fun updateStatusText() {
        val target = activeTarget
        binding.castStatus.text = when {
            target != null && target.isConnected -> getString(R.string.cast_connected, target.name)
            castUnavailable -> getString(R.string.cast_unavailable)
            castContext == null -> getString(R.string.cast_initializing)
            else -> getString(R.string.cast_disconnected)
        }
    }

    private fun updateControlBar() {
        val target = activeTarget
        val connected = target != null && target.isConnected
        binding.controlBar.visibility = if (connected) View.VISIBLE else View.GONE
        binding.openRemoteControlButton.isEnabled = connected
        val hasMedia = target != null && target.playbackState !in listOf(PlaybackState.IDLE, PlaybackState.ERROR)
        binding.playPauseButton.isEnabled = hasMedia
        binding.stopButton.isEnabled = hasMedia
        binding.playPauseButton.setText(
            if (target?.playbackState == PlaybackState.PLAYING) R.string.pause else R.string.play
        )
    }

    // ───────────────────────── Casting a video ─────────────────────────

    private fun castVideo(video: DetectedVideo) {
        val target = activeTarget
        if (target == null || !target.isConnected) {
            showDevicePickerDialog(video)
            return
        }
        if (video.isDrm) {
            AlertDialog.Builder(this)
                .setTitle(R.string.drm_detected)
                .setMessage(R.string.drm_explanation)
                .setPositiveButton(R.string.close, null)
                .show()
            return
        }
        // Android exige iniciar o serviço enquanto a tela ainda está visível.
        if (!started) return
        val requestId = ++castLoadRequestId
        try {
            val pendingSeek = if (target.protocol == CastProtocol.GOOGLE_CAST) 0L else incomingResumePositionMs
            CastingService.start(this, target, mediaProxy, video.title, pendingSeek)
        } catch (_: Exception) {
            CastSessionEvents.error("service_unavailable")
            toast(getString(R.string.cast_load_error, 0))
            return
        }
        target.loadMedia(video, mediaProxy, binding.webView.settings.userAgentString) { success ->
            runOnUiThread {
                if (requestId != castLoadRequestId || !CastingService.owns(mediaProxy)) return@runOnUiThread
                if (success) {
                    CastingService.mediaAccepted(target)
                    incomingResumePositionMs = 0L
                    frameMediaObserver?.transport?.pauseLocalPlayback()
                    binding.webView.evaluateJavascript("document.querySelectorAll('video,audio').forEach(function(v){v.pause();});", null)
                } else {
                    stopService(Intent(this, CastingService::class.java))
                    CastSessionEvents.error("load_failed")
                }
                if (isDestroyed || isFinishing) return@runOnUiThread
                if (success) {
                    toast(getString(R.string.cast_request_accepted))
                    if (started) RemoteControlActivity.launch(this@MainActivity)
                    binding.castStatus.postDelayed({
                        if (!isDestroyed && !isFinishing && requestId == castLoadRequestId &&
                            activeTarget === target &&
                            target.playbackState == PlaybackState.IDLE
                        ) toast(getString(R.string.cast_playback_not_started))
                    }, 10_000)
                } else {
                    toast(getString(R.string.cast_load_error, 0))
                }
                updateControlBar()
            }
        }
    }

    // ───────────────────────── Device Picker Dialog ─────────────────────────

    fun showDevicePickerDialog(pendingVideo: DetectedVideo? = null) {
        pickerPendingVideo = pendingVideo
        attachCastRouteDiscovery()
        val devices = deviceDiscovery.allDevices.filter { it.protocol != CastProtocol.GOOGLE_CAST }
        val currentGoogle = activeTarget?.takeIf { it.protocol == CastProtocol.GOOGLE_CAST && it.isConnected }
        val routes = googleCastRoutes()
        val entries = mutableListOf<DevicePickerEntry>()
        if (currentGoogle != null && routes.none { it.isSelected && it.name == currentGoogle.name }) {
            entries += DevicePickerEntry(currentGoogle.name, target = currentGoogle)
        }
        routes.forEach { route ->
            entries += DevicePickerEntry(route.name, route = route)
        }
        devices.forEach { item ->
            val icon = when (item.protocol) {
                CastProtocol.GOOGLE_CAST -> "📡 Google Cast"
                CastProtocol.DLNA -> "📺 DLNA (Smart TV)"
                CastProtocol.ROKU -> "🟣 Roku TV"
            }
            val active = if (item.name == activeTarget?.name && item.protocol == activeTarget?.protocol) " (Conectado)" else ""
            entries += DevicePickerEntry("$icon: ${item.name}$active", target = item)
        }

        if (entries.isEmpty()) {
            val dialog = AlertDialog.Builder(this)
                .setTitle("Transmitir para TV")
                .setMessage("Procurando Google Cast, Roku e Smart TVs na mesma rede Wi-Fi...\n\nCertifique-se de que a TV está ligada e conectada à mesma rede.")
                .setPositiveButton("Buscar Novamente") { _, _ ->
                    dlnaDiscovery?.start()
                    rokuDiscovery?.start()
                    attachCastRouteDiscovery()
                    binding.castStatus.postDelayed({
                        if (!isDestroyed && !isFinishing) showDevicePickerDialog(pendingVideo)
                    }, 3000)
                }
                .setNegativeButton(R.string.close, null)
                .create()
            pickerDialog = dialog
            waitingForGoogleCastRoutes = true
            dialog.setOnDismissListener {
                if (pickerDialog === dialog) pickerDialog = null
                waitingForGoogleCastRoutes = false
            }
            dialog.show()
            return
        }

        val dialog = AlertDialog.Builder(this)
            .setTitle("Selecione sua TV")
            .setItems(entries.map { it.label }.toTypedArray()) { _, index ->
                val selected = entries[index]
                val route = selected.route
                if (route != null) {
                    pendingVideoForGoogleCast = pendingVideo
                    try {
                        route.select()
                        toast("Conectando a ${route.name}…")
                        if (route.isSelected) onCastSessionChanged()
                    } catch (error: Exception) {
                        pendingVideoForGoogleCast = null
                        android.util.Log.w("CastLite", "Google Cast route selection failed: ${error.javaClass.simpleName}")
                        toast("Não foi possível conectar à ${route.name}.")
                    }
                } else {
                    val target = selected.target ?: return@setItems
                    pendingVideoForGoogleCast = null
                    setActiveTarget(target)
                    toast("Conectado a ${target.name}")
                    pendingVideo?.let { castVideo(it) }
                }
            }
            .setNegativeButton(R.string.close, null)
            .create()
        pickerDialog = dialog
        dialog.setOnDismissListener {
            if (pickerDialog === dialog) pickerDialog = null
            waitingForGoogleCastRoutes = false
        }
        dialog.show()
    }

    // ───────────────────────── CiNey Bridge ─────────────────────────

    private fun handleIncomingIntent(intent: Intent?): Boolean {
        if (intent == null) return false
        if (intent.hasExtra(CastRequest.EXTRA)) {
            try {
                CastRequestIntent.read(intent)?.let { openInternalRequest(it) }
            } catch (_: Exception) {
                CastSessionEvents.error("invalid_request")
                toast(getString(R.string.cast_invalid_request))
                finish()
            }
            return true
        }
        val action = intent.action
        val data = intent.data

        var targetUrl: String? = null
        var title: String? = null
        var isEmbed = false
        var positionMs = 0L

        if (Intent.ACTION_VIEW == action && data != null) {
            if (data.scheme == "castlite" || data.scheme == "cineycast") {
                targetUrl = data.getQueryParameter("url")
                title = data.getQueryParameter("title")
                isEmbed = data.getQueryParameter("isEmbed") == "true"
                positionMs = data.getQueryParameter("position")?.toLongOrNull() ?: 0L
            } else if (data.scheme in listOf("http", "https")) {
                targetUrl = data.toString()
            }
        } else if (Intent.ACTION_SEND == action && intent.type == "text/plain") {
            targetUrl = intent.getStringExtra(Intent.EXTRA_TEXT)
            title = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        }

        intent.getStringExtra("url")?.let { targetUrl = it }
        intent.getStringExtra("title")?.let { title = it }
        if (intent.hasExtra("isEmbed")) isEmbed = intent.getBooleanExtra("isEmbed", isEmbed)
        if (intent.hasExtra("position")) positionMs = intent.getLongExtra("position", positionMs)

        if (!targetUrl.isNullOrBlank()) {
            val resolvedUrl = BrowserAddress.resolve(targetUrl) ?: targetUrl
            incomingTitle = title
            incomingResumePositionMs = positionMs

            val isDirectStream = !isEmbed && (
                resolvedUrl.contains(".m3u8", ignoreCase = true) ||
                resolvedUrl.contains(".mp4", ignoreCase = true) ||
                resolvedUrl.contains(".mkv", ignoreCase = true) ||
                resolvedUrl.contains(".webm", ignoreCase = true)
            )

            if (isDirectStream) {
                val mime = VideoDetector.mimeTypeFor(resolvedUrl, null) ?: "video/mp4"
                val directVideo = DetectedVideo(
                    url = resolvedUrl,
                    title = title ?: "CiNey Vídeo",
                    pageUrl = resolvedUrl,
                    mimeType = mime
                )
                videos.beginPage()
                mediaRequestHeaders.clear()
                videos.add(directVideo, videos.pageId)
                updateVideosButton()
                currentPageUrl = resolvedUrl
                binding.urlInput.setText(resolvedUrl)
                showDevicePickerDialog(directVideo)
            } else {
                autoCastOnDetect = true
                isIncomingEmbed = isEmbed || resolvedUrl.contains("superflixapi") || resolvedUrl.contains("myembed")
                incomingTargetHost = try { Uri.parse(resolvedUrl).host?.lowercase() } catch (_: Exception) { null }
                currentPageUrl = resolvedUrl
                binding.urlInput.setText(resolvedUrl)

                if (isIncomingEmbed) {
                    // SuperFlix e EmbedMovies exigem carregamento via <iframe>.
                    // Se abertos diretamente no topo (window.top), mostram erro de 'Acesso Restrito - Visualização Externa'.
                    val embedHtml = """
                        <!doctype html>
                        <html lang="pt-BR">
                        <head>
                          <meta charset="utf-8">
                          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                          <style>
                            html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
                            iframe { width: 100%; height: 100%; border: 0; display: block; }
                          </style>
                        </head>
                        <body>
                          <iframe src="$resolvedUrl" allow="autoplay; encrypted-media; picture-in-picture; fullscreen" frameborder="0" allowfullscreen webkitallowfullscreen mozallowfullscreen></iframe>
                        </body>
                        </html>
                    """.trimIndent()
                    val baseOrigin = try {
                        val uri = Uri.parse(resolvedUrl)
                        "${uri.scheme}://${uri.host}/"
                    } catch (_: Exception) {
                        "https://superflixapi.quest/"
                    }
                    videos.beginPage()
                    mediaRequestHeaders.clear()
                    updateVideosButton()
                    binding.webView.loadDataWithBaseURL(baseOrigin, embedHtml, "text/html", "UTF-8", resolvedUrl)
                } else {
                    binding.webView.loadUrl(resolvedUrl)
                }
            }
            return true
        }
        return false
    }

    private fun openInternalRequest(request: CastRequest) {
        castLoadRequestId++
        pendingVideoForGoogleCast = null
        pickerDialog?.dismiss()
        waitingForGoogleCastRoutes = false
        incomingRequest = request
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        incomingTitle = request.title
        incomingResumePositionMs = request.positionMs
        val source = request.source
        isIncomingEmbed = source.isEmbed
        incomingTargetHost = Uri.parse(source.url).host?.lowercase()
        currentPageUrl = source.url
        binding.urlInput.setText(source.url)
        binding.toolbar.title = request.title.ifBlank { getString(R.string.app_name) }
        videos.beginPage()
        mediaRequestHeaders.clear()
        mediaRequestHeaders[source.url] = source.headers
        updateVideosButton()
        invalidateOptionsMenu()
        CastSessionEvents.opening(request)
        val mime = if (source.isEmbed || !source.isDirect) null
            else VideoDetector.mimeTypeFor(source.url, source.mimeType)
        autoCastOnDetect = mime == null
        if (mime != null) {
            val video = DetectedVideo(source.url, request.title, source.url, mime, source.headers,
                posterUrl = request.posterUrl, audioLanguage = source.audioLanguage,
                resumePositionMs = request.positionMs)
            videos.add(video, videos.pageId)
            updateVideosButton()
            // onCreate ocorre antes de onStart; a seleção deve abrir após a tela ficar visível.
            binding.root.post { if (!isFinishing && !isDestroyed) castVideo(video) }
        } else if (source.isEmbed) {
            val escapedUrl = TextUtils.htmlEncode(source.url)
            val html = """<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
                <body style="margin:0;background:#000"><iframe src="$escapedUrl" style="border:0;width:100%;height:100vh"
                allow="autoplay; encrypted-media; fullscreen; picture-in-picture" allowfullscreen></iframe></body></html>"""
            val uri = Uri.parse(source.url)
            binding.webView.loadDataWithBaseURL("${uri.scheme}://${uri.authority}/", html, "text/html", "UTF-8", source.url)
        } else {
            binding.webView.loadUrl(source.url, source.headers)
        }
    }

    // ───────────────────────── UI setup ─────────────────────────

    private fun setupUi() {
        binding.castButton.setOnClickListener { showDevicePickerDialog() }
        binding.castStatus.setOnClickListener { showDevicePickerDialog() }
        binding.urlInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_GO) { loadFromInput(); true } else false
        }
        binding.goButton.setOnClickListener { loadFromInput() }
        // Uma nova varredura também encontra tags inseridas após onPageFinished.
        binding.videosButton.setOnClickListener { scanPage { showVideosDialog() } }
        binding.playPauseButton.setOnClickListener {
            activeTarget?.let { target ->
                if (target.playbackState == PlaybackState.PLAYING) target.pause() else target.play()
            }
        }
        binding.stopButton.setOnClickListener {
            activeTarget?.stop()
            if (activeTarget === CastingService.target) stopService(Intent(this, CastingService::class.java))
        }
        binding.openRemoteControlButton.setOnClickListener {
            RemoteControlActivity.launch(this)
        }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (binding.webView.canGoBack()) binding.webView.goBack()
                else { isEnabled = false; onBackPressedDispatcher.onBackPressed() }
            }
        })
        updateVideosButton()
    }

    private fun loadFromInput() {
        val url = BrowserAddress.resolve(binding.urlInput.text.toString()) ?: return
        binding.webView.loadUrl(url)
        (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager)
            .hideSoftInputFromWindow(binding.urlInput.windowToken, 0)
        binding.urlInput.clearFocus()
        binding.webView.requestFocus()
    }

    private fun updateVideosButton() {
        binding.videosButton.text = getString(R.string.videos_detected, videos.size)
    }

    private fun showVideosDialog() {
        val list = videos.snapshot()
        if (list.isEmpty()) { toast(getString(R.string.no_videos)); return }
        val pageId = videos.pageId
        val labels = list.mapIndexed { index, video ->
            val prefix = if (video.isDrm) "🔒 " else ""
            "$prefix${index + 1}. ${video.label}"
        }.toTypedArray()
        AlertDialog.Builder(this)
            .setTitle(R.string.videos_title)
            .setItems(labels) { _, index ->
                if (videos.pageId == pageId) castVideo(list[index]) else toast(getString(R.string.page_changed))
            }
            .setNegativeButton(R.string.close, null)
            .show()
    }

    private fun toast(message: String) = Toast.makeText(this, message, Toast.LENGTH_LONG).show()

    // ───────────────────────── WebView ─────────────────────────

    @SuppressLint("SetJavaScriptEnabled")
    private fun setupWebView() {
        binding.webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            mediaPlaybackRequiresUserGesture = false
            mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
            allowFileAccess = false
            allowContentAccess = false
            setSupportMultipleWindows(false)
            javaScriptCanOpenWindowsAutomatically = false
            userAgentString = userAgentString.replace("; wv", "")
        }
        binding.webView.webViewClient = object : WebViewClient() {
            // Executado em segundo plano: não acessa propriedades do WebView aqui.
            override fun shouldInterceptRequest(view: WebView?, request: WebResourceRequest?): WebResourceResponse? {
                val pageId = videos.pageId
                request?.let { resource ->
                    val url = resource.url.toString()
                    // Usa Accept header como dica de tipo para detecção
                    val acceptType = resource.requestHeaders?.entries
                        ?.firstOrNull { it.key.equals("Accept", ignoreCase = true) }
                        ?.value?.takeIf { it.startsWith("video/") || it.contains("mpegurl", ignoreCase = true) }
                    val headers = resource.requestHeaders
                    runOnUiThread {
                        if (isDestroyed || isFinishing || videos.pageId != pageId) return@runOnUiThread
                        mediaRequestHeaders[url] = headers
                        if (mediaRequestHeaders.size > 256) mediaRequestHeaders.remove(mediaRequestHeaders.keys.first())
                        val existing = videos.snapshot().firstOrNull { it.url == url }
                        addVideo(url, acceptType ?: existing?.mimeType, pageId, headers,
                            existing?.pageUrl ?: currentPageUrl)
                    }
                }
                return null // O WebView continua responsável por rede, cookies e TLS.
            }

            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val url = request?.url ?: return false
                val scheme = url.scheme?.lowercase().orEmpty()
                if (scheme !in listOf("http", "https")) {
                    if (request.isForMainFrame) toast(getString(R.string.unsupported_link))
                    return true
                }
                // Bloqueia redirecionamentos de anúncios da janela principal quando estamos em modo embed
                if (isIncomingEmbed && request.isForMainFrame) {
                    val host = url.host?.lowercase().orEmpty()
                    val targetHost = incomingTargetHost
                    if (targetHost != null &&
                        !host.contains(targetHost) &&
                        !host.contains("cloudflare") &&
                        !host.contains("turnstile") &&
                        !host.contains("superflix") &&
                        !host.contains("myembed")
                    ) {
                        android.util.Log.d("CastLite", "Bloqueando redirecionamento de anúncio externo: $url")
                        return true
                    }
                }
                return false
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                if (!isIncomingEmbed || url == currentPageUrl) {
                    beginPage(url.orEmpty())
                }
            }

            override fun doUpdateVisitedHistory(view: WebView?, url: String?, isReload: Boolean) {
                // Navegações internas de sites SPA também não devem manter vídeos da tela anterior.
                if (url != null && url.substringBefore('#') != currentPageUrl.substringBefore('#') && !isIncomingEmbed) {
                    beginPage(url)
                }
                invalidateOptionsMenu()
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                if (url != view?.url && !isIncomingEmbed) return
                scanPage()
                invalidateOptionsMenu()
            }

            override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
                if (request?.isForMainFrame == true && !isIncomingEmbed) {
                    binding.progress.visibility = View.GONE
                    toast(getString(R.string.page_error))
                }
            }
        }
        binding.webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                binding.progress.progress = newProgress
                binding.progress.visibility = if (newProgress in 1..99) View.VISIBLE else View.GONE
            }
        }
        binding.webView.setDownloadListener { url, _, _, mime, _ ->
            addVideo(url, mime, videos.pageId)
        }
        frameMediaObserver = FrameMediaObserver(binding.webView, { videos.pageId }) { url, type, pageUrl, pageId ->
            addVideo(url, type, pageId, sourcePageUrl = pageUrl)
        }
        mediaProxy.frameTransport = frameMediaObserver?.transport
    }

    private fun beginPage(url: String) {
        frameMediaObserver?.transport?.close()
        currentPageUrl = url
        videos.beginPage()
        mediaRequestHeaders.clear()
        updateVideosButton()
        binding.urlInput.setText(url)
        invalidateOptionsMenu()
        // A requisição principal pode chegar antes de onPageStarted: conserva links diretos.
        addVideo(url, null, videos.pageId)
    }

    private fun addVideo(
        url: String,
        declaredType: String?,
        pageId: Long,
        requestHeaders: Map<String, String> = emptyMap(),
        sourcePageUrl: String = currentPageUrl
    ) {
        val mime = VideoDetector.mimeTypeFor(url, declaredType) ?: return
        runOnUiThread {
            if (isDestroyed || isFinishing || videos.pageId != pageId) return@runOnUiThread
            val relayHeaders = (incomingRequest?.source?.headers.orEmpty() + mediaRequestHeaders[url].orEmpty() + requestHeaders).filterKeys { name ->
                listOf("User-Agent", "Referer", "Origin", "Accept", "Accept-Language", "Authorization", "Cookie")
                    .any { it.equals(name, ignoreCase = true) }
            }
            val title = incomingTitle ?: binding.webView.title?.takeIf { it.isNotBlank() } ?: Uri.parse(url).lastPathSegment ?: url
            val video = DetectedVideo(url, title, sourcePageUrl, mime, relayHeaders,
                posterUrl = incomingRequest?.posterUrl, audioLanguage = incomingRequest?.source?.audioLanguage,
                resumePositionMs = incomingResumePositionMs)
            if (videos.add(video, pageId)) {
                android.util.Log.d("CastLite-Detect", "Detected ${VideoDetector.typeName(mime)} from ${Uri.parse(sourcePageUrl).host}; count=${videos.size}")
                updateVideosButton()
                if (autoCastOnDetect) {
                    autoCastOnDetect = false
                    showDevicePickerDialog(video)
                }
            }
        }
    }

    private fun scanPage(onComplete: (() -> Unit)? = null) {
        frameMediaObserver?.refresh()
        val pageId = videos.pageId
        binding.webView.evaluateJavascript(FIND_VIDEOS_JS) { result ->
            if (isDestroyed || isFinishing || videos.pageId != pageId) return@evaluateJavascript
            try {
                val array = JSONArray(result)
                for (i in 0 until array.length()) {
                    val item = array.optJSONObject(i) ?: continue
                    addVideo(item.optString("url"), item.optString("type"), pageId)
                }
            } catch (_: Exception) {
                // Algumas páginas não permitem executar a varredura; a interceptação continua ativa.
            }
            onComplete?.invoke()
        }
    }

    companion object {
        private const val HOME_URL = "https://www.google.com"
        private val FIND_VIDEOS_JS = """
            (function() {
                var found = [];
                document.querySelectorAll('video, source').forEach(function(element) {
                    var type = element.getAttribute('type') || '';
                    if (element.currentSrc) found.push({url: element.currentSrc, type: type});
                    if (element.src) found.push({url: element.src, type: type});
                });
                return found;
            })();
        """.trimIndent()
    }
}
