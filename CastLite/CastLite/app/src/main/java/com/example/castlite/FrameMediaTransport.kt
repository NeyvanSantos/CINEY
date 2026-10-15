package com.example.castlite

import android.os.Handler
import android.os.Looper
import android.util.Base64
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.WebViewFeature
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

/** Mantém as requisições no navegador de origem; não exporta cookies. */
internal class FrameMediaTransport : Closeable {
    data class Response(val status: Int, val type: String, val body: ByteArray, val finalUrl: String, val contentRange: String)
    private data class Frame(val pageId: Long, val origin: String, val reply: JavaScriptReplyProxy)
    private class Pending(val frame: Frame) {
        val done = CountDownLatch(1)
        val bytes = ByteArrayOutputStream()
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
        val request = Pending(frame)
        pending[id] = request
        try {
            val message = JSONObject().put("kind", "fetch").put("id", id)
                .put("pageId", frame.pageId).put("url", url).put("range", range).toString()
            ui.post {
                if (frames[pageUrl] !== frame || !WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
                    request.done.countDown()
                } else runCatching { frame.reply.postMessage(message) }.onFailure { request.done.countDown() }
            }
            request.done.await(45, TimeUnit.SECONDS)
            return request.result
        } finally {
            pending.remove(id)
            slots.release()
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
                }
                "fetchChunk" -> {
                    val bytes = Base64.decode(data.getString("data"), Base64.DEFAULT)
                    check(request.bytes.size() + bytes.size <= MAX_BYTES)
                    request.bytes.write(bytes)
                }
                "fetchEnd" -> {
                    if (request.status in 200..599 && VideoDetector.isHttpUrl(request.finalUrl)) {
                        request.result = Response(request.status, request.type, request.bytes.toByteArray(), request.finalUrl, request.contentRange)
                    }
                    request.done.countDown()
                }
                "fetchError" -> request.done.countDown()
            }
        } catch (_: Exception) {
            pending.remove(data.optString("id"))
            request.done.countDown()
        }
    }

    override fun close() {
        frames.clear()
        pending.values.forEach { it.done.countDown() }
        pending.clear()
    }

    private companion object { const val MAX_BYTES = 16 * 1024 * 1024 }
}
