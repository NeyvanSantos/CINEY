package com.example.castlite

import android.net.Uri
import android.util.Log
import android.webkit.WebView
import androidx.webkit.ScriptHandler
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import org.json.JSONObject
import java.io.Closeable

/** Observes each frame in its own origin; messages only supply media metadata. */
class FrameMediaObserver(
    private val webView: WebView,
    private val currentPageId: () -> Long,
    private val onVideo: (String, String, String, Long) -> Unit
) : Closeable {
    internal val transport = FrameMediaTransport(webView.context.cacheDir)
    private var script: ScriptHandler? = null

    init {
        if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER) &&
            WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)
        ) {
            WebViewCompat.addWebMessageListener(webView, "CastLiteMedia", setOf("*")) {
                    _, message, sourceOrigin, _, reply ->
                if (message.type != WebMessageCompat.TYPE_STRING) return@addWebMessageListener
                val text = message.data ?: return@addWebMessageListener
                if (text.length > 65_536) return@addWebMessageListener
                val data = runCatching { JSONObject(text) }.getOrNull() ?: return@addWebMessageListener
                if (data.optString("kind").startsWith("fetch")) {
                    transport.receive(data, sourceOrigin.toString())
                    return@addWebMessageListener
                }
                if (data.optString("kind") == "ready") {
                    reply.postMessage(currentPageId().toString())
                    return@addWebMessageListener
                }
                val pageId = data.optLong("pageId", -1)
                if (data.optString("kind") != "media" || pageId != currentPageId()) return@addWebMessageListener
                val pageUrl = data.optString("pageUrl")
                if (!VideoDetector.isHttpUrl(pageUrl)) return@addWebMessageListener
                val page = Uri.parse(pageUrl)
                if (page.scheme != sourceOrigin.scheme || page.host != sourceOrigin.host ||
                    page.port != sourceOrigin.port
                ) return@addWebMessageListener
                transport.register(pageUrl, pageId, sourceOrigin.toString(), reply)
                val sources = data.optJSONArray("sources") ?: return@addWebMessageListener
                for (index in 0 until minOf(sources.length(), 64)) {
                    val source = sources.optJSONObject(index) ?: continue
                    onVideo(source.optString("url"), source.optString("type"), pageUrl, pageId)
                }
            }
            val javascript = webView.context.assets.open("media_observer.js").bufferedReader().use { it.readText() }
            if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
                script = WebViewCompat.addDocumentStartJavaScript(webView, javascript, setOf("*"))
            }
            Log.d("CastLite-Detect", "Frame media observer enabled")
        } else {
            Log.w("CastLite-Detect", "Frame observation unavailable in this WebView version")
        }
    }

    fun refresh() {
        webView.evaluateJavascript("window.__castLiteMediaObserver && window.__castLiteMediaObserver.refresh();", null)
    }

    override fun close() {
        transport.close()
        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) script?.remove()
        if (script != null && WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            WebViewCompat.removeWebMessageListener(webView, "CastLiteMedia")
        }
        script = null
    }
}
