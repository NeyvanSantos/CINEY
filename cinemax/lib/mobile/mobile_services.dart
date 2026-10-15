import 'package:castlite_engine/castlite_engine.dart';
import 'package:ciney_core/core/platform/app_platform_services.dart';
import 'package:embed_media_observer/embed_media_observer.dart';
import 'mobile_announcements.dart';
import 'mobile_push_service.dart';
import 'notification_settings_screen.dart';

import '../features/auth/presentation/tv_pairing_scanner_screen.dart';

void configureMobileServices() {
  AppPlatformServices.current = AppPlatformServices(
    casting: const _NativeCastingSender(),
    frameObserver: const _NativeFrameObserver(),
    scannerBuilder: (_) => const TvPairingScannerScreen(),
    announcements: MobileAnnouncements.instance,
    notificationSettingsBuilder: (_) => const NotificationSettingsScreen(),
    appWrapper: (_, child) => MobilePushHost(child: child),
    beforeSignOut: MobilePushService.instance.beforeSignOut,
  );
}

class _NativeCastingSender implements CastingSender {
  const _NativeCastingSender();

  @override
  Future<bool> isAvailable() => CastLiteEngine.isAvailable();

  @override
  Future<void> open(Map<String, Object?> request) =>
      CastLiteEngine.open(request);
}

class _NativeFrameObserver implements MediaFrameObserver {
  const _NativeFrameObserver();

  @override
  Future<bool> install(int webViewId, String script) =>
      EmbedMediaObserver.install(webViewId, script);

  @override
  Future<void> remove(int webViewId) => EmbedMediaObserver.remove(webViewId);
}
