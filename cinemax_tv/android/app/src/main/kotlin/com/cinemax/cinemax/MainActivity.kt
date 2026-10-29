package com.cinemax.cinemax

import com.ciney.embedmedia.BrowserMediaTransport
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.MotionEvent
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var playbackResult: MethodChannel.Result? = null
    private var playbackChannel: MethodChannel? = null
    fun nativePlayerReady(retainBrowserSession: Boolean) {
        // Flutter does not draw frames while its Activity is stopped. Release
        // provider playback now rather than waiting for a Dart widget rebuild.
        findWebView(window.decorView)?.let { view ->
            if (activeTransport != null && retainBrowserSession) {
                activeTransport?.pauseLocalPlayback()
                // JavaScript and the message bridge remain our HLS transport.
                // Pause the provider's video, not the WebView supplying bytes.
                view.onResume()
            } else {
                activeTransport?.close()
                activeTransport = null
                view.stopLoading()
                view.loadUrl("about:blank")
                view.onPause()
            }
        }
        Log.i("CINEY_NATIVE", "browserRetained=$retainBrowserSession")
        playbackChannel?.invokeMethod("ready", null)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 7241) {
            playbackResult?.success(mapOf(
                "positionMs" to (data?.getLongExtra("positionMs", 0) ?: 0),
                "durationMs" to (data?.getLongExtra("durationMs", 0) ?: 0),
                "error" to (data?.getBooleanExtra("error", true) ?: true),
                "completed" to (data?.getBooleanExtra("completed", false) ?: false),
                "sources" to (data?.getBooleanExtra("sources", false) ?: false)))
            if (data?.getBooleanExtra("error", true) != false) activeTransport?.resumeLocalPlayback()
            playbackResult = null
            activeHost = null
            activeTransport = null
        }
    }
    companion object {
        var activeHost: MainActivity? = null
        var activeTransport: BrowserMediaTransport? = null
    }
    private val handler = Handler(Looper.getMainLooper())

    override fun onPause() {
        super.onPause()
        if (activeTransport != null) {
            // The browser-session window stays visible, but Flutter's loading
            // animation must not compete with video decoding on low-RAM TVs.
            // onResume restores the normal Flutter lifecycle on return.
            flutterEngine?.lifecycleChannel?.appIsPaused()
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN &&
            (event.keyCode == KeyEvent.KEYCODE_DPAD_CENTER || event.keyCode == KeyEvent.KEYCODE_ENTER)) {
            findWebView(window.decorView)?.let { BrowserMediaTransport.recordConfirm(it) }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (packageName.endsWith(".lite_test")) {
            WebView.setWebContentsDebuggingEnabled(true)
        }
        playbackChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ciney/tv_native_player")
        playbackChannel!!.setMethodCallHandler { call, result ->
            if (call.method != "open") { result.notImplemented(); return@setMethodCallHandler }
            if (playbackResult != null) { result.error("busy", "Player ocupado", null); return@setMethodCallHandler }
            val url = call.argument<String>("url")
            if (url == null || !(url.startsWith("https://") || url.startsWith("http://"))) {
                result.error("invalid_url", "Midia invalida", null); return@setMethodCallHandler
            }
            playbackResult = result
            activeHost = this
            val page = call.argument<String>("pageUrl")
            activeTransport = if (call.argument<Boolean>("browserSession") == true) {
                findWebView(window.decorView)?.let { BrowserMediaTransport.get(it) }?.takeIf { it.hasPage(page) }
            } else null
            val playerActivity = if (activeTransport != null) BrowserSessionTvPlayerActivity::class.java
                else NativeTvPlayerActivity::class.java
            val request = Intent(this, playerActivity)
            request.putExtra("url", url)
            request.putExtra("pageUrl", page)
            request.putExtra("browserSession", activeTransport != null)
            request.putExtra("title", call.argument<String>("title"))
            request.putExtra("positionMs", call.argument<Number>("positionMs")?.toLong() ?: 0)
            request.putExtra("portuguese", call.argument<Boolean>("portuguese") ?: true)
            request.putExtra("headers", java.util.HashMap(call.argument<Map<String, String>>("headers") ?: emptyMap()))
            try { startActivityForResult(request, 7241) } catch (e: Exception) {
                playbackResult = null; activeHost = null
                result.error("launch_failed", "Nao foi possivel abrir o player", null)
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.cinemax.cinemax/tv_pointer",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "tap" -> dispatchVirtualPointerTap(
                    call.argument<Double>("x"),
                    call.argument<Double>("y"),
                    result,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun dispatchVirtualPointerTap(
        normalizedX: Double?,
        normalizedY: Double?,
        result: MethodChannel.Result,
        attempt: Int = 0,
    ) {
        if (normalizedX == null || normalizedY == null ||
            !normalizedX.isFinite() || !normalizedY.isFinite()
        ) {
            result.error("INVALID_POINTER_POSITION", "Coordenadas inválidas.", null)
            return
        }

        val webView = findWebView(window.decorView)
        if (webView == null || webView.width <= 1 || webView.height <= 1) {
            if (attempt < 5) {
                handler.postDelayed({
                    dispatchVirtualPointerTap(normalizedX, normalizedY, result, attempt + 1)
                }, 50)
            } else {
                result.error("WEBVIEW_NOT_FOUND", "Player embed ainda não está pronto.", null)
            }
            return
        }

        val x = (normalizedX.coerceIn(0.0, 1.0) * webView.width)
            .coerceIn(1.0, (webView.width - 1).toDouble())
            .toFloat()
        val y = (normalizedY.coerceIn(0.0, 1.0) * webView.height)
            .coerceIn(1.0, (webView.height - 1).toDouble())
            .toFloat()
        webView.requestFocus()

        val downTime = SystemClock.uptimeMillis()
        val downEvent = MotionEvent.obtain(
            downTime,
            downTime,
            MotionEvent.ACTION_DOWN,
            x,
            y,
            0,
        )
        webView.dispatchTouchEvent(downEvent)
        downEvent.recycle()

        handler.postDelayed({
            if (!webView.isAttachedToWindow) {
                result.success(false)
                return@postDelayed
            }
            val upEvent = MotionEvent.obtain(
                downTime,
                SystemClock.uptimeMillis(),
                MotionEvent.ACTION_UP,
                x,
                y,
                0,
            )
            val handled = webView.dispatchTouchEvent(upEvent)
            upEvent.recycle()
            result.success(handled)
        }, 70)
    }

    private fun findWebView(view: View): WebView? {
        if (view is WebView) return view
        if (view !is ViewGroup) return null

        for (index in 0 until view.childCount) {
            findWebView(view.getChildAt(index))?.let { return it }
        }
        return null
    }
}
