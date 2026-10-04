package com.cinemax.cinemax

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Window
import androidx.mediarouter.app.MediaRouteChooserDialog
import androidx.mediarouter.media.MediaRouteSelector
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.common.images.WebImage
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "com.cinemax.cinemax/cast"
    private val webVideoCasterPackage = "com.instantbits.cast.webvideo"
    private var allowedEmbedHosts = mutableSetOf(
        "myembed.biz",
        "www.myembed.biz",
        "embedmovies.org",
        "www.embedmovies.org",
        "playerflix.ink",
        "www.playerflix.ink",
        "vidlink.pro",
        "www.vidlink.pro",
        "superflixapi.monster",
        "www.superflixapi.monster",
        "localhost",
        "127.0.0.1"
    )
    private val receiverNamespace = "urn:x-cast:com.cinemax.receiver"
    private val googleHomePackage = "com.google.android.apps.chromecast.app"
    private var castContext: CastContext? = null
    private var pendingCast: PendingCast? = null
    private var chooserDialog: MediaRouteChooserDialog? = null
    private val handler = Handler(Looper.getMainLooper())
    private val connectionTimeout = Runnable {
        if (pendingCast != null && castContext?.sessionManager?.currentCastSession?.isConnected != true) {
            failPending("A conexão com a TV expirou. Confirme que os aparelhos estão no mesmo Wi-Fi.")
        }
    }

    private data class PendingCast(
        val url: String,
        val title: String,
        val posterUrl: String?,
        val contentType: String,
        val isEmbed: Boolean,
        val result: MethodChannel.Result
    )

    private val sessionListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarted(session: CastSession, sessionId: String) = loadPending(session)
        override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) = loadPending(session)
        override fun onSessionStarting(session: CastSession) = Unit
        override fun onSessionStartFailed(session: CastSession, error: Int) = failPending("Não foi possível conectar ao Chromecast.")
        override fun onSessionEnding(session: CastSession) = Unit
        override fun onSessionEnded(session: CastSession, error: Int) = Unit
        override fun onSessionResuming(session: CastSession, sessionId: String) = Unit
        override fun onSessionResumeFailed(session: CastSession, error: Int) = failPending("A conexão com o Chromecast falhou.")
        override fun onSessionSuspended(session: CastSession, reason: Int) = Unit
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            castContext = CastContext.getSharedInstance(this)
            castContext?.sessionManager?.addSessionManagerListener(sessionListener, CastSession::class.java)
        } catch (error: Exception) {
            castContext = null
            // Abrir o Google Home não depende da inicialização do Cast SDK.
            Log.w("CinemaxCast", "Google Cast não está disponível neste aparelho.", error)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "castMedia" -> castMedia(
                    call.argument("url"),
                    call.argument<String>("title") ?: "Filme / Série",
                    call.argument("posterUrl"),
                    call.argument<String>("contentType") ?: "video/mp4",
                    result
                )
                "isCastConnected" -> result.success(
                    castContext?.sessionManager?.currentCastSession?.isConnected == true
                )
                "castDeviceName" -> result.success(
                    castContext?.sessionManager?.currentCastSession?.castDevice?.friendlyName
                )
                "stopCasting" -> {
                    handler.removeCallbacks(connectionTimeout)
                    pendingCast?.result?.success(false)
                    pendingCast = null
                    castContext?.sessionManager?.endCurrentSession(true)
                    result.success(true)
                }
                "openSystemCast" -> openSystemCast(result)
                "openGoogleHome" -> openGoogleHome(result)
                "openGoogleHomeStore" -> openGoogleHomeStore(result)
                "openExternalPlayer" -> openExternalPlayer(call.argument("url"), call.argument<String>("title") ?: "Vídeo", result)
                "openWebVideoCaster" -> openWebVideoCaster(call.argument("url"), call.argument<String>("title") ?: "Vídeo", result)
                "openWebVideoCasterStore" -> openWebVideoCasterStore(result)
                "updateAllowedHosts" -> {
                    val hosts = call.argument<List<String>>("hosts")
                    if (hosts != null && hosts.isNotEmpty()) {
                        allowedEmbedHosts = hosts.map { it.lowercase(Locale.ROOT) }.toMutableSet()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "getAllowedHosts" -> result.success(allowedEmbedHosts.toList())
                else -> result.notImplemented()
            }
        }
    }

    private fun castMedia(url: String?, title: String, posterUrl: String?, contentType: String, result: MethodChannel.Result) {
        if (url == null || url.isBlank()) {
            result.error("INVALID_URL", "O Chromecast precisa de um link HTTP válido para a reprodução.", null)
            return
        }

        val uri = Uri.parse(url)
        if (uri.scheme !in listOf("http", "https") || uri.host.isNullOrBlank()) {
            result.error("INVALID_URL", "A fonte precisa ser uma URL HTTP válida.", null)
            return
        }

        pendingCast?.result?.success(false)
        pendingCast = PendingCast(
            url,
            title,
            posterUrl,
            contentType,
            !isDirectMediaUrl(url),
            result
        )
        handler.removeCallbacks(connectionTimeout)
        val activeSession = castContext?.sessionManager?.currentCastSession
        if (activeSession?.isConnected == true) {
            loadPending(activeSession)
            return
        }
        val context = castContext ?: run {
            failPending("Google Cast não está disponível neste aparelho.")
            return
        }
        chooserDialog?.dismiss()
        chooserDialog = MediaRouteChooserDialog(this).apply {
            routeSelector = context.mergedSelector ?: MediaRouteSelector.EMPTY
            requestWindowFeature(Window.FEATURE_NO_TITLE)
            show()
        }
        handler.postDelayed(connectionTimeout, 60_000)
    }

    private fun loadPending(session: CastSession) {
        val request = pendingCast ?: return
        if (request.isEmbed) {
            val message = JSONObject()
                .put("type", "LOAD")
                .put("title", request.title)
                .put("url", request.url)
                .put("poster", request.posterUrl)
                .toString()
            session.sendMessage(receiverNamespace, message).setResultCallback { status ->
                if (status.isSuccess) completePending(true)
                else failPending("O receiver do CineMax não aceitou esta fonte EmbedMovies.")
            }
            return
        }
        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE).apply {
            putString(MediaMetadata.KEY_TITLE, request.title)
            request.posterUrl?.takeIf { it.startsWith("http") }?.let { addImage(WebImage(Uri.parse(it))) }
        }
        val mediaInfo = MediaInfo.Builder(request.url)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(request.contentType)
            .setMetadata(metadata)
            .build()
        val loadRequest = MediaLoadRequestData.Builder().setMediaInfo(mediaInfo).setAutoplay(true).build()
        session.remoteMediaClient?.load(loadRequest)?.setResultCallback { loadResult ->
            if (loadResult.status.isSuccess) completePending(true)
            else failPending("A TV recusou esta fonte de vídeo (${loadResult.status.statusCode}).")
        } ?: failPending("A sessão conectou, mas não aceitou o vídeo.")
    }

    private fun completePending(success: Boolean) {
        val result = pendingCast?.result ?: return
        pendingCast = null
        handler.removeCallbacks(connectionTimeout)
        runOnUiThread { result.success(success) }
    }

    private fun failPending(message: String) {
        val result = pendingCast?.result ?: return
        pendingCast = null
        handler.removeCallbacks(connectionTimeout)
        runOnUiThread { result.error("CAST_ERROR", message, null) }
    }

    private fun openSystemCast(result: MethodChannel.Result) {
        try {
            startActivity(Intent(Settings.ACTION_CAST_SETTINGS))
            result.success(true)
        } catch (_: Exception) {
            try {
                startActivity(Intent("android.settings.WIFI_DISPLAY_SETTINGS"))
                result.success(true)
            } catch (error: Exception) {
                result.error("CAST_ERROR", "Não foi possível abrir o espelhamento de tela.", error.message)
            }
        }
    }

    private fun openGoogleHome(result: MethodChannel.Result) {
        try {
            val intent = packageManager.getLaunchIntentForPackage(googleHomePackage)
            if (intent == null) {
                result.error("HOME_NOT_INSTALLED", "Instale o Google Home para espelhar a tela na TV.", null)
                return
            }
            startActivity(intent)
            // Isso confirma apenas a abertura do Google Home, não o espelhamento.
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.error("HOME_NOT_INSTALLED", "Instale o Google Home para espelhar a tela na TV.", null)
        } catch (error: Exception) {
            result.error("HOME_LAUNCH_ERROR", "Não foi possível abrir o Google Home.", error.message)
        }
    }

    private fun openGoogleHomeStore(result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$googleHomePackage"))
                .setPackage("com.android.vending")
            startActivity(intent)
            result.success(true)
        } catch (_: Exception) {
            try {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$googleHomePackage")))
                result.success(true)
            } catch (error: Exception) {
                result.error("HOME_STORE_ERROR", "Não foi possível abrir a página do Google Home na loja.", error.message)
            }
        }
    }

    private fun isDirectMediaUrl(url: String): Boolean {
        val uri = Uri.parse(url)
        val scheme = uri.scheme?.lowercase(Locale.ROOT)
        val path = uri.path?.lowercase(Locale.ROOT) ?: return false
        return scheme in listOf("http", "https") &&
            !uri.host.isNullOrBlank() &&
            listOf(".mp4", ".m3u8", ".mpd", ".webm", ".mkv").any { path.endsWith(it) }
    }

    private fun openExternalPlayer(url: String?, title: String, result: MethodChannel.Result) {
        if (url == null || !isDirectMediaUrl(url)) {
            result.error("INVALID_URL", "O player externo precisa de um link HTTP direto para o vídeo.", null)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse(url), "video/*")
                putExtra("title", title)
            }
            startActivity(Intent.createChooser(intent, "Transmitir / Reproduzir com:"))
            result.success(true)
        } catch (error: Exception) {
            result.error("INTENT_ERROR", "Erro ao abrir player externo", error.message)
        }
    }

    private fun openWebVideoCaster(url: String?, title: String, result: MethodChannel.Result) {
        if (url == null || url.isBlank()) {
            result.error("INVALID_URL", "O Web Video Caster precisa de uma URL HTTP válida.", null)
            return
        }
        val launchIntent = packageManager.getLaunchIntentForPackage(webVideoCasterPackage)
        if (launchIntent == null) {
            result.error(
                "WEB_VIDEO_CASTER_NOT_INSTALLED",
                "O Web Video Caster não está instalado.",
                null
            )
            return
        }
        val sourceUri = Uri.parse(url)
        if (sourceUri.scheme !in listOf("http", "https") || sourceUri.host.isNullOrBlank()) {
            result.error("INVALID_URL", "A fonte precisa ser uma URL HTTP válida.", null)
            return
        }
        Thread {
            val redirectHost = findExternalRedirectHost(url)
            runOnUiThread {
                if (redirectHost != null) {
                    result.error(
                        "UNSAFE_REDIRECT",
                        "A fonte redirecionou para um domínio externo e foi bloqueada: $redirectHost",
                        null
                    )
                    return@runOnUiThread
                }
                try {
                    val intent = Intent(Intent.ACTION_VIEW, sourceUri).apply {
                        setPackage(webVideoCasterPackage)
                        putExtra("title", title)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (error: Exception) {
                    result.error("WEB_VIDEO_CASTER_ERROR", "Não foi possível abrir o Web Video Caster.", error.message)
                }
            }
        }.start()
    }

    private fun findExternalRedirectHost(sourceUrl: String): String? {
        var currentUrl = sourceUrl
        repeat(4) {
            val connection = (URL(currentUrl).openConnection() as HttpURLConnection).apply {
                instanceFollowRedirects = false
                connectTimeout = 5000
                readTimeout = 5000
                requestMethod = "GET"
                setRequestProperty("User-Agent", "CineMax/1.0")
            }
            try {
                val status = connection.responseCode
                if (status !in 300..399) return null
                val location = connection.getHeaderField("Location") ?: return null
                val next = URL(URL(currentUrl), location)
                val host = next.host.lowercase(Locale.ROOT)
                if (!isAllowedHost(host)) return host
                currentUrl = next.toString()
            } finally {
                connection.disconnect()
            }
        }
        return null
    }

    private fun isAllowedHost(host: String): Boolean {
        val h = host.lowercase(Locale.ROOT)
        if (h in allowedEmbedHosts) return true
        if (h == "localhost" || h == "127.0.0.1" || h.startsWith("192.168.") || h.startsWith("10.") || h.startsWith("172.")) return true
        return false
    }

    private fun openWebVideoCasterStore(result: MethodChannel.Result) {
        try {
            val intent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("market://details?id=$webVideoCasterPackage")
            ).setPackage("com.android.vending")
            startActivity(intent)
            result.success(true)
        } catch (_: Exception) {
            try {
                startActivity(Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/apps/details?id=$webVideoCasterPackage")
                ))
                result.success(true)
            } catch (error: Exception) {
                result.error("WEB_VIDEO_CASTER_STORE_ERROR", "Não foi possível abrir a loja.", error.message)
            }
        }
    }

    override fun onDestroy() {
        castContext?.sessionManager?.removeSessionManagerListener(sessionListener, CastSession::class.java)
        super.onDestroy()
    }
}
