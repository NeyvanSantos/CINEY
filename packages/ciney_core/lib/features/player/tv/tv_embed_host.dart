import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'tv_webview_bridge.dart';
import '../../../core/platform/app_platform_services.dart';
import '../../../plugin_engine/models/stream_source.dart';
import 'tv_hls_candidate.dart';

/// Platform adapter: Android-specific setup stays outside the TV UI.
/// Future TV platforms can supply their own host without changing source APIs.
class TvEmbedHost {
  TvEmbedHost()
    : controller = WebViewController(
        onPermissionRequest: (request) => request.deny(),
      );

  final WebViewController controller;
  bool _released = false;
  int? get viewId => controller.platform is AndroidWebViewController
      ? (controller.platform as AndroidWebViewController).webViewIdentifier
      : null;

  Future<bool> observeHls(
    StreamSource provider,
    void Function(TvHlsCandidate) onCandidate, {
    void Function(String)? onMenuState,
  }) async {
    await controller.addJavaScriptChannel(
      'TvMediaBridge',
      onMessageReceived: (message) {
        final candidate = TvHlsCandidate.parse(message.message);
        if (!_released && candidate != null) onCandidate(candidate);
        if (!_released && candidate == null && message.message.length <= 4096) {
          try {
            final event = jsonDecode(message.message);
            if (event is Map &&
                event['event'] == 'remoteMenu' &&
                const [
                  'ready',
                  'selected',
                  'audio',
                ].contains(event['action'])) {
              onMenuState?.call(event['action'] as String);
            }
          } on FormatException {
            // Other frame messages do not change the playback session.
          }
        }
      },
    );
    final id = viewId;
    if (id == null) return false;
    final uri = Uri.parse(provider.url);
    final startup = await rootBundle.loadString(
      'packages/ciney_core/assets/player/embed_startup.js',
    );
    final observer = await rootBundle.loadString(
      'packages/ciney_core/assets/player/tv_hls_observer.js',
    );
    final navigation = await rootBundle.loadString(
      'packages/ciney_core/assets/player/tv_remote_navigation.js',
    );
    if (_released) return false;
    final installed = await AppFrameObserver.install(
      id,
      'window.__cineyAutoStart = true;\n'
      'window.__cineyIsTv = true;\n'
      'window.__cineyProviderHost = ${jsonEncode(uri.host)};\n'
      'window.__cineyProviderPath = ${jsonEncode(uri.path)};\n'
      '$navigation\n$startup\n$observer',
    );
    if (_released) await AppFrameObserver.remove(id);
    return installed && !_released;
  }

  Future<Map<String, String>> playbackHeaders(String url) async {
    final id = viewId;
    if (id == null || _released) return {};
    try {
      return await TvWebViewBridge.channel.invokeMapMethod<String, String>(
            'playbackHeaders',
            {'webViewId': id, 'url': url},
          ) ??
          {};
    } on MissingPluginException {
      return {};
    }
  }

  Future<void> configure({
    required void Function(Widget, VoidCallback) onFullscreen,
    required VoidCallback onHideFullscreen,
  }) async {
    final platform = controller.platform;
    if (platform is! AndroidWebViewController) return;
    await platform.setMediaPlaybackRequiresUserGesture(false);
    final cookies = WebViewCookieManager().platform;
    if (cookies is AndroidWebViewCookieManager) {
      await cookies.setAcceptThirdPartyCookies(platform, true);
    }
    await platform.setCustomWidgetCallbacks(
      onShowCustomWidget: onFullscreen,
      onHideCustomWidget: onHideFullscreen,
    );
  }

  Future<void> release() async {
    if (_released) return;
    _released = true;
    final id = viewId;
    try {
      if (id != null) await AppFrameObserver.remove(id);
    } finally {
      final released =
          id != null && await TvWebViewBridge.invoke('release', id);
      if (!released) await controller.loadRequest(Uri.parse('about:blank'));
    }
  }
}
