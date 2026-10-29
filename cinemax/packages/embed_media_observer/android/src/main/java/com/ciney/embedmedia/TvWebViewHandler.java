package com.ciney.embedmedia;

import android.view.KeyEvent;
import android.view.MotionEvent;
import android.os.SystemClock;
import android.os.Handler;
import android.os.Looper;
import android.webkit.WebView;
import android.webkit.CookieManager;
import android.net.Uri;
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
    private final Map<Long, Long> confirms = new HashMap<>();

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
                case "playbackHeaders":
                    String mediaUrl = call.argument("url");
                    Uri mediaUri = mediaUrl == null ? null : Uri.parse(mediaUrl);
                    if (!attached.containsKey(id) || mediaUri == null ||
                        !("https".equals(mediaUri.getScheme()) || "http".equals(mediaUri.getScheme())) ||
                        mediaUri.getHost() == null || mediaUri.getUserInfo() != null) {
                        result.error("invalid_media", "Invalid media URL", null);
                        return;
                    }
                    Map<String, String> headers = new HashMap<>();
                    headers.put("User-Agent", view.getSettings().getUserAgentString());
                    String cookie = CookieManager.getInstance().getCookie(mediaUrl);
                    if (cookie != null && !cookie.isEmpty()) headers.put("Cookie", cookie);
                    result.success(headers);
                    return;
                case "attach":
                    attached.put(id, view);
                    BrowserMediaTransport.attach(view);
                    view.getSettings().setDomStorageEnabled(true);
                    CookieManager.getInstance().setAcceptCookie(true);
                    view.setFocusable(true);
                    view.setFocusableInTouchMode(true);
                    view.setOnKeyListener((v, code, event) -> {
                        if ((code == KeyEvent.KEYCODE_DPAD_CENTER || code == KeyEvent.KEYCODE_ENTER)
                                && event.getAction() == KeyEvent.ACTION_DOWN) {
                            confirms.put(id, SystemClock.uptimeMillis());
                        }
                        if (code == KeyEvent.KEYCODE_DPAD_CENTER) {
                            // Chromium consistently exposes Enter to provider scripts.
                            return view.dispatchKeyEvent(new KeyEvent(
                                event.getDownTime(), event.getEventTime(), event.getAction(),
                                KeyEvent.KEYCODE_ENTER, event.getRepeatCount(), event.getMetaState()));
                        }
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
                case "tap":
                    Number nx = call.argument("x"), ny = call.argument("y");
                    Long confirmed = confirms.remove(id);
                    boolean recentConfirm = BrowserMediaTransport.consumeConfirm(view) ||
                        (confirmed != null && SystemClock.uptimeMillis() - confirmed <= 1500);
                    android.util.Log.i("CINEY_REMOTE", "tap confirmed="+recentConfirm+" size="+view.getWidth()+"x"+view.getHeight());
                    if (!recentConfirm ||
                        nx == null || ny == null || !Double.isFinite(nx.doubleValue()) ||
                        !Double.isFinite(ny.doubleValue()) || nx.doubleValue() < 0 ||
                        nx.doubleValue() > 1 || ny.doubleValue() < 0 || ny.doubleValue() > 1) {
                        result.success(false); return;
                    }
                    float x = (float)(nx.doubleValue() * view.getWidth());
                    float y = (float)(ny.doubleValue() * view.getHeight());
                    long downTime = SystemClock.uptimeMillis();
                    MotionEvent down = MotionEvent.obtain(downTime, downTime, MotionEvent.ACTION_DOWN, x, y, 0);
                    view.dispatchTouchEvent(down); down.recycle();
                    new Handler(Looper.getMainLooper()).postDelayed(() -> {
                        if (!view.isAttachedToWindow()) { result.success(false); return; }
                        MotionEvent up = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), MotionEvent.ACTION_UP, x, y, 0);
                        boolean handled = view.dispatchTouchEvent(up); up.recycle(); result.success(handled);
                    }, 70);
                    return;
                case "key":
                    Number key = call.argument("keyCode");
                    if (key == null || !allowedKey(key.intValue())) { result.success(false); return; }
                    if (key.intValue() == 23 || key.intValue() == 66) BrowserMediaTransport.recordConfirm(view);
                    view.requestFocus();
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
        confirms.remove(id);
        WebView view = attached.remove(id);
        if (view == null) return;
        BrowserMediaTransport.detach(view);
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
