import 'package:ciney_core/core/platform/app_platform_services.dart';
import 'package:flutter/services.dart';
import 'package:embed_media_observer/embed_media_observer.dart';

void configureTvServices() {
  AppPlatformServices.current = AppPlatformServices(
    tvPlayback: _playDedicated,
    frameObserver: _TvFrameObserver(),
  );
}

class _TvFrameObserver implements MediaFrameObserver {
  const _TvFrameObserver();

  @override
  Future<bool> install(int webViewId, String script) =>
      EmbedMediaObserver.install(webViewId, script);

  @override
  Future<void> remove(int webViewId) => EmbedMediaObserver.remove(webViewId);
}

const _playerChannel = MethodChannel('com.ciney/tv_native_player');
Future<Map<String, Object?>?> _playDedicated(
  Map<String, Object?> request,
  void Function() onReady,
) async {
  _playerChannel.setMethodCallHandler((call) async {
    if (call.method == 'ready') onReady();
  });
  try {
    return await _playerChannel.invokeMapMethod<String, Object?>(
      'open',
      request,
    );
  } finally {
    _playerChannel.setMethodCallHandler(null);
  }
}
