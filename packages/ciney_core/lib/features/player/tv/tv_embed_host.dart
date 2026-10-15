import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'tv_webview_bridge.dart';

/// Platform adapter: Android-specific setup stays outside the TV UI.
/// Future TV platforms can supply their own host without changing source APIs.
class TvEmbedHost {
  TvEmbedHost()
    : controller = WebViewController(
        onPermissionRequest: (request) => request.deny(),
      );

  final WebViewController controller;
  int? get viewId => controller.platform is AndroidWebViewController
      ? (controller.platform as AndroidWebViewController).webViewIdentifier
      : null;

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
    final id = viewId;
    final released = id != null && await TvWebViewBridge.invoke('release', id);
    if (!released) await controller.loadRequest(Uri.parse('about:blank'));
  }
}
