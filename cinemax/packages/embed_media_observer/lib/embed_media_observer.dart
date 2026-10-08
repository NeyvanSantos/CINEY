import 'package:flutter/services.dart';

/// Install before loading the iframe document. Unsupported WebViews return false.
class EmbedMediaObserver {
  static const _channel = MethodChannel('com.ciney/embed_media_observer');

  static Future<bool> install(int webViewId, String script) async {
    try {
      return await _channel.invokeMethod<bool>('install', {
            'webViewId': webViewId,
            'script': script,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> remove(int webViewId) async {
    try {
      await _channel.invokeMethod<void>('remove', {'webViewId': webViewId});
    } on MissingPluginException {
      // Non-Android hosts use the parent document bridge.
    }
  }
}
