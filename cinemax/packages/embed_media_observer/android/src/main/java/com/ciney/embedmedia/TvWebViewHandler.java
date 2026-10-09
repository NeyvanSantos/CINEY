package com.ciney.embedmedia;

import android.view.KeyEvent;
import android.webkit.WebView;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi;
import java.util.HashMap;
import java.util.Map;

/** TV-only focus/key delivery. No coordinate taps or cross-origin DOM access. */
final class TvWebViewHandler implements MethodChannel.MethodCallHandler {
    private final FlutterEngine engine;
    private final MethodChannel channel;
    private final Map<Long, WebView> attached = new HashMap<>();

    TvWebViewHandler(FlutterEngine engine, BinaryMessenger messenger) {
        this.engine = engine;
        channel = new MethodChannel(messenger, "com.ciney/tv_webview");
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
        try {
            if (call.method.equals("release")) {
                release(id);
                result.success(true);
                return;
            }
            WebView view = WebViewFlutterAndroidExternalApi.getWebView(engine, id);
            if (view == null) { result.success(false); return; }
            switch (call.method) {
                case "attach":
                    attached.put(id, view);
                    view.setFocusable(true);
                    view.setFocusableInTouchMode(true);
                    view.setOnKeyListener((v, code, event) -> {
                        if (code != KeyEvent.KEYCODE_MENU && code != KeyEvent.KEYCODE_BACK) return false;
                        if (event.getAction() == KeyEvent.ACTION_UP) {
                            Map<String, Object> args = new HashMap<>();
                            args.put("webViewId", id);
                            channel.invokeMethod(code == KeyEvent.KEYCODE_MENU ? "menu" : "back", args);
                        }
                        return true;
                    });
                    break;
                case "focus": view.onResume(); view.requestFocus(); break;
                case "blur": view.clearFocus(); break;
                case "key":
                    Number key = call.argument("keyCode");
                    if (key == null || !allowedKey(key.intValue())) { result.success(false); return; }
                    view.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, key.intValue()));
                    view.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_UP, key.intValue()));
                    break;
                default: result.notImplemented(); return;
            }
            result.success(true);
        } catch (RuntimeException error) {
            result.error("tv_webview_failed", "WebView operation failed", null);
        }
    }

    private boolean allowedKey(int code) {
        return code == 19 || code == 20 || code == 21 || code == 22 || code == 23 ||
            code == 66 || code == 85 || code == 86 || code == 126 || code == 127;
    }

    private void release(long id) {
        WebView view = attached.remove(id);
        if (view == null) return;
        view.setOnKeyListener(null);
        view.stopLoading();
        view.loadUrl("about:blank");
        view.onPause();
        // Flutter owns the platform view and destroys it when unmounted.
    }

    void dispose() {
        channel.setMethodCallHandler(null);
        for (Long id : attached.keySet().toArray(new Long[0])) release(id);
    }
}
