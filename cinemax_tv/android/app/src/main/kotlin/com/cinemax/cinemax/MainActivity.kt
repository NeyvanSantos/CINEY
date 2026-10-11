package com.cinemax.cinemax

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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