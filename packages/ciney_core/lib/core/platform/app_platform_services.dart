import 'package:flutter/widgets.dart';

/// Capacidades fornecidas pelo host. O núcleo não importa plugins de celular.
abstract interface class CastingSender {
  Future<bool> isAvailable();
  Future<void> open(Map<String, Object?> request);
}

abstract interface class MediaFrameObserver {
  Future<bool> install(int webViewId, String script);
  Future<void> remove(int webViewId);
}

abstract interface class AnnouncementPresenter {
  Future<void> initialize();
  Future<void> show({
    required int id,
    required String title,
    required String body,
  });
}

class AppPlatformServices {
  const AppPlatformServices({
    this.casting,
    this.frameObserver,
    this.scannerBuilder,
    this.announcements,
  });

  static AppPlatformServices current = const AppPlatformServices();

  final CastingSender? casting;
  final MediaFrameObserver? frameObserver;
  final WidgetBuilder? scannerBuilder;
  final AnnouncementPresenter? announcements;
}

class AppFrameObserver {
  static Future<bool> install(int webViewId, String script) async =>
      await AppPlatformServices.current.frameObserver?.install(
        webViewId,
        script,
      ) ??
      false;

  static Future<void> remove(int webViewId) async {
    await AppPlatformServices.current.frameObserver?.remove(webViewId);
  }
}
