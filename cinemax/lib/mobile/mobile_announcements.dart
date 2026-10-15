import 'dart:convert';

import 'package:ciney_core/core/platform/app_platform_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class MobileAnnouncements implements AnnouncementPresenter {
  MobileAnnouncements._();
  static final instance = MobileAnnouncements._();
  final plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;
  void Function(Map<String, dynamic>)? onTap;
  static const channel = AndroidNotificationChannel(
    'ciney_announcements',
    'Avisos CiNey',
    description: 'Novidades do catálogo e do aplicativo CiNey',
    importance: Importance.high,
  );

  void _handlePayload(String? payload) {
    if (payload == null) return;
    try {
      final value = jsonDecode(payload);
      if (value is Map<String, dynamic>) onTap?.call(value);
    } on FormatException catch (_) {
      // Old/manual announcements have no navigation payload.
    }
  }

  @override
  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _handlePayload(response.payload),
    );
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _handlePayload(launch?.notificationResponse?.payload);
    }
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) => showPush(id: id, title: title, body: body);

  Future<void> showPush({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? tag,
  }) async {
    await initialize();
    await plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          color: const Color(0xFFFF6B00),
          tag: tag,
        ),
      ),
      payload: data == null ? null : jsonEncode(data),
    );
  }
}
