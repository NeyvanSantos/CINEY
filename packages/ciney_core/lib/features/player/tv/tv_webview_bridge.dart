import 'dart:async';
import 'package:flutter/services.dart';
import '../../../core/services/app_logger.dart';

class TvWebViewBridge {
  static const channel = MethodChannel('com.ciney/tv_webview');
  static final _events =
      StreamController<({int id, String action})>.broadcast();
  static bool _initialized = false;
  static Stream<({int id, String action})> get events {
    if (!_initialized) {
      _initialized = true;
      channel.setMethodCallHandler((call) async {
        final args = call.arguments;
        if (args is Map && args['webViewId'] is int) {
          _events.add((id: args['webViewId'] as int, action: call.method));
        }
      });
    }
    return _events.stream;
  }

  static Future<bool> invoke(String method, int id, {int? keyCode}) async {
    try {
      return await channel.invokeMethod<bool>(method, {
            'webViewId': id,
            'keyCode': ?keyCode,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      AppLogger.warn(
        'Controle WebView indisponível (${error.code}).',
        tag: 'TV_ENGINE',
      );
      return false;
    }
  }
}
