import 'package:flutter/material.dart';
import '../platform/app_platform_services.dart';

/// Avisos na TV sem serviço, permissão ou plugin de notificação Android.
class InAppAnnouncementPresenter implements AnnouncementPresenter {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _pending = <int, ({String title, String body})>{};
  bool _scheduled = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    _pending[id] = (title: title, body: body);
    flushAfterFrame();
  }

  void flushAfterFrame() {
    if (_scheduled || _pending.isEmpty) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      final messenger = messengerKey.currentState;
      if (messenger == null) return;
      final notices = _pending.values.toList();
      _pending.clear();
      for (final notice in notices) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${notice.title}\n${notice.body}'),
            duration: const Duration(seconds: 8),
            showCloseIcon: true,
          ),
        );
      }
    });
  }
}
