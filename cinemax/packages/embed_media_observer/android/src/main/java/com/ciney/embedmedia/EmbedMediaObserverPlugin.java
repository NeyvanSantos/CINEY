package com.ciney.embedmedia;

import android.webkit.WebView;
import androidx.webkit.ScriptHandler;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

/** Uses the public WebView Flutter API without changing app activities. */
public final class EmbedMediaObserverPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private FlutterEngine engine;
    private MethodChannel channel;
    private final Map<Long, ScriptHandler> scripts = new HashMap<>();

    @Override
    @SuppressWarnings("deprecation")
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        engine = binding.getFlutterEngine();
        channel = new MethodChannel(binding.getBinaryMessenger(), "com.ciney/embed_media_observer");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        Number identifier = call.argument("webViewId");
        if (identifier == null) {
            result.error("invalid_view", "Missing WebView identifier", null);
            return;
        }
        long id = identifier.longValue();
        if (call.method.equals("remove")) {
            remove(id);
            result.success(null);
            return;
        }
        if (!call.method.equals("install")) {
            result.notImplemented();
            return;
        }
        WebView view = WebViewFlutterAndroidExternalApi.getWebView(engine, id);
        if (view == null || !WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            result.success(false);
            return;
        }
        String script = call.argument("script");
        if (script == null) {
            result.error("invalid_script", "Missing observer script", null);
            return;
        }
        try {
            remove(id);
            // Provider players can use nested frames on different origins.
            // This script only reports media; it grants no additional native APIs.
            scripts.put(id, WebViewCompat.addDocumentStartJavaScript(view, script, Collections.singleton("*")));
            result.success(true);
        } catch (RuntimeException error) {
            result.error("observer_failed", error.getMessage(), null);
        }
    }

    private void remove(long id) {
        ScriptHandler script = scripts.remove(id);
        if (script != null) script.remove();
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        for (ScriptHandler script : scripts.values()) script.remove();
        scripts.clear();
        engine = null;
    }
}
