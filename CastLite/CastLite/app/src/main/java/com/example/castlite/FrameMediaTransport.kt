package com.example.castlite

import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import android.util.Base64
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.WebViewFeature
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.atomic.AtomicBoolean
import java.io.Closeable
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

/** Mantém as requisições no navegador de origem; não exporta cookies. */
internal class FrameMediaTransport(private val cacheDirectory: File) : Closeable {
    data class Response(val status: Int, val type: String, val body: InputStream, val finalUrl: String, val contentRange: String)
    private data class Frame(val pageId: Long, val origin: String, val reply: JavaScriptReplyProxy)
    private class Pending(val frame: Frame, val body: RelaySpool) {
        val done = CountDownLatch(1)
        val released = AtomicBoolean(false)
        var status = 0
        var type = ""
        var finalUrl = ""
        var contentRange = ""
        var result: Response? = null
    }
    private val ui = Handler(Looper.getMainLooper())
    private val frames = ConcurrentHashMap<String, Frame>()
    private val pending = ConcurrentHashMap<String, Pending>()
    private val slots = Semaphore(4)

    fun register(pageUrl: String, pageId: Long, origin: String, reply: JavaScriptReplyProxy) {
        frames[pageUrl] = Frame(pageId, origin, reply)
    }

    fun pauseLocalPlayback() {
        ui.post {
            if (!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) return@post
            frames.values.forEach { frame ->
                runCatching { frame.reply.postMessage("{\"kind\":\"pauseLocal\"}") }
            }
        }
    }

    // Executado somente pelo relay, com URLs já registradas no catálogo/manifesto.
    fun fetch(pageUrl: String, url: String, range: String?): Response? {
        val frame = frames[pageUrl] ?: return null
        if (!slots.tryAcquire(5, TimeUnit.SECONDS)) return null
        val id = UUID.randomUUID().toString()
        val request = try { Pending(frame, RelaySpool(cacheDirectory)) } catch (_: IOException) {
            slots.release()
            return null
        }
        pending[id] = request
        var delivered = false
        try {
            val message = JSONObject().put("kind", "fetch").put("id", id)
                .put("pageId", frame.pageId).put("url", url).put("range", range).toString()
            ui.post {
                if (frames[pageUrl] !== frame || !WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
                    request.done.countDown()
                } else runCatching {
                    val credentials = if (!RelayHeaderPolicy.sameOrigin(pageUrl, url) &&
                        !CookieManager.getInstance().getCookie(url).isNullOrBlank()) "include" else "same-origin"
                    frame.reply.postMessage(JSONObject(message).put("credentials", credentials).toString())
                }.onFailure { request.done.countDown() }
            }
            request.done.await(45, TimeUnit.SECONDS)
            val response = request.result
            delivered = response != null
            return response
        } finally {
            if (!delivered) release(id, request)
        }
    }

    private fun release(id: String, request: Pending) {
        if (!request.released.compareAndSet(false, true)) return
        pending.remove(id, request)
        request.body.close()
        slots.release()
        ui.post {
            if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
                runCatching { request.frame.reply.postMessage(
                    JSONObject().put("kind", "cancelFetch").put("id", id).toString()) }
            }
        }
    }

    fun receive(data: JSONObject, origin: String) {
        val request = pending[data.optString("id")] ?: return
        if (origin != request.frame.origin || data.optLong("pageId", -1) != request.frame.pageId) return
        try {
            when (data.optString("kind")) {
                "fetchStart" -> {
                    request.status = data.optInt("status")
                    request.type = data.optString("type")
                    request.finalUrl = data.optString("url")
                    request.contentRange = data.optString("contentRange")
                    if (request.status in 200..599 && VideoDetector.isHttpUrl(request.finalUrl)) {
                        val id = data.optString("id")
                        val body = object : java.io.FilterInputStream(request.body) {
                            override fun close() { release(id, request) }
                        }
                        request.result = Response(request.status, request.type, body, request.finalUrl, request.contentRange)
                    }
                    request.done.countDown()
                }
                "fetchChunk" -> {
                    val bytes = Base64.decode(data.getString("data"), Base64.DEFAULT)
                    request.body.append(bytes)
                }
                "fetchEnd" -> {
                    request.body.finish()
                    request.done.countDown()
                }
                "fetchError" -> {
                    request.body.finish(IOException("Browser media request failed"))
                    request.done.countDown()
                }
            }
        } catch (_: Exception) {
            request.body.finish(IOException("Browser media transfer failed"))
            request.done.countDown()
        }
    }

    override fun close() {
        frames.clear()
        pending.entries.toList().forEach { (id, request) ->
            request.done.countDown()
            release(id, request)
        }
    }

}
