import 'package:ciney_core/core/platform/app_platform_services.dart';
import 'package:embed_media_observer/embed_media_observer.dart';

void configureTvServices() {
  AppPlatformServices.current = const AppPlatformServices(
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
