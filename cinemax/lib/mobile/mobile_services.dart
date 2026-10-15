import 'package:castlite_engine/castlite_engine.dart';
import 'package:ciney_core/core/platform/app_platform_services.dart';
import 'package:embed_media_observer/embed_media_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../features/auth/presentation/tv_pairing_scanner_screen.dart';

void configureMobileServices() {
  AppPlatformServices.current = AppPlatformServices(
    casting: const _NativeCastingSender(),
    frameObserver: const _NativeFrameObserver(),
    scannerBuilder: (_) => const TvPairingScannerScreen(),
    announcements: _SystemAnnouncementPresenter(),
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

class _SystemAnnouncementPresenter implements AnnouncementPresenter {
  static const _channelId = 'ciney_announcements';
  static const _channelName = 'Avisos CiNey';
  static const _description =
      'Mensagens e novidades enviadas pela equipe CiNey';
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _description,
        importance: Importance.high,
      ),
    );
    await android?.requestNotificationsPermission();
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) => _plugin.show(
    id,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _description,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: Color(0xFFFF6B00),
      ),
    ),
  );
}
