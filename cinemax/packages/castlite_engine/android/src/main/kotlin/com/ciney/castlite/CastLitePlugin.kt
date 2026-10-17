package com.ciney.castlite

import android.app.Activity
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Handler
import android.os.Looper
import com.example.castlite.CastRequest
import com.example.castlite.CastSessionEvents
import com.example.castlite.CastingService
import com.example.castlite.MainActivity
import com.example.castlite.RemoteControlActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class CastLitePlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var activity: Activity? = null
    private var sink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private val listener: (Map<String, Any?>) -> Unit = { state ->
        handler.post { sink?.success(state) }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "com.ciney/castlite")
        methods.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "com.ciney/castlite/events")
        events.setStreamHandler(this)
    }

    private fun available(): Boolean =
        context.getSystemService(UiModeManager::class.java)?.currentModeType != Configuration.UI_MODE_TYPE_TELEVISION

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "isAvailable") { result.success(available()); return }
        if (call.method == "getState") { result.success(CastSessionEvents.snapshot()); return }
        if (!available()) { result.error("unavailable", "Transmissão indisponível neste dispositivo.", null); return }
        try {
            when (call.method) {
                "open" -> open(call, result)
                "showControls" -> {
                    val host = requireActivity()
                    if (CastingService.target == null) error("no_session")
                    host.startActivity(Intent(host, RemoteControlActivity::class.java))
                    result.success(null)
                }
                "play", "pause", "stop", "seek" -> {
                    val target = CastingService.target ?: error("no_session")
                    when (call.method) {
                        "play" -> { CastingService.setUserPaused(false); target.play() }
                        "pause" -> { CastingService.setUserPaused(true); target.pause() }
                        "stop" -> { target.stop(); context.stopService(Intent(context, CastingService::class.java)) }
                        "seek" -> {
                            val position = call.argument<Number>("positionMs")?.toLong() ?: -1
                            require(position >= 0) { "invalid_position" }
                            target.seek(position)
                        }
                    }
                    CastSessionEvents.update(CastingService.target)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: IllegalArgumentException) {
            result.error("invalid_request", "Dados de transmissão inválidos.", null)
        } catch (_: IllegalStateException) {
            result.error("unavailable", "Abra o CiNey ou conecte um dispositivo para continuar.", null)
        } catch (_: Exception) {
            result.error("cast_failed", "Não foi possível abrir a transmissão.", null)
        }
    }

    private fun requireActivity(): Activity = activity?.takeUnless { it.isFinishing || it.isDestroyed }
        ?: error("no_activity")

    private fun open(call: MethodCall, result: MethodChannel.Result) {
        val host = requireActivity()
        val request = CastRequest.fromMap(call.arguments as? Map<*, *> ?: error("invalid_request"))
        val payload = JSONObject(request.toMap()).toString()
        require(payload.toByteArray(Charsets.UTF_8).size <= 250_000) { "request_too_large" }
        host.startActivity(Intent(host, MainActivity::class.java).apply {
            putExtra(CastRequest.EXTRA, payload)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        })
        result.success(null)
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
        sink = eventSink
        CastSessionEvents.addListener(listener)
        eventSink.success(CastSessionEvents.snapshot())
    }

    override fun onCancel(arguments: Any?) {
        CastSessionEvents.removeListener(listener)
        sink = null
        handler.removeCallbacksAndMessages(null)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        onCancel(null)
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        activity = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }
}
