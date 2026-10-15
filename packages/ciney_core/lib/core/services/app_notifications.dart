import 'dart:async';

import 'package:flutter/material.dart' show GlobalKey, ScaffoldMessengerState;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_logger.dart';
import '../platform/app_platform_services.dart';
import 'in_app_announcements.dart';

/// Notificações de aviso escritas pelo administrador no Supabase.
///
/// A tabela `app_notifications` é consultada na abertura do app; quando há
/// uma mensagem ativa ainda não vista pelo aparelho, ela é exibida como
/// aviso do host e marcada como lida localmente.
class AppNotifications {
  AppNotifications._();

  static const _lastSeenKey = 'last_seen_notification_id';

  static final _inApp = InAppAnnouncementPresenter();
  static AnnouncementPresenter get _presenter =>
      AppPlatformServices.current.announcements ?? _inApp;
  static GlobalKey<ScaffoldMessengerState> get messengerKey =>
      _inApp.messengerKey;
  static void flushPending() => _inApp.flushAfterFrame();
  static bool _initialized = false;

  /// O mobile prepara seu canal; a TV apresenta os avisos dentro do aplicativo.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _presenter.initialize();
      _initialized = true;
    } catch (error) {
      AppLogger.warn(
        'Notificações indisponíveis (${error.runtimeType}).',
        tag: 'NOTIFY',
      );
    }
  }

  /// Busca o aviso ativo mais recente e notifica se o aparelho ainda não viu.
  static Future<void> checkAndNotify(SupabaseClient? client) async {
    if (client == null) return;
    try {
      await initialize();
      if (!_initialized) return;

      final row = await client
          .from('app_notifications')
          .select('id, title, body')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return;

      await _showIfNew(row);
    } catch (error) {
      AppLogger.warn(
        'Falha ao verificar avisos (${error.runtimeType}).',
        tag: 'NOTIFY',
      );
    }
  }

  static RealtimeChannel? _liveChannel;

  /// Entrega instantânea: enquanto o app estiver aberto, qualquer aviso
  /// publicado no Supabase chega na hora via Realtime.
  static void watchLive(SupabaseClient? client) {
    if (client == null || _liveChannel != null) return;
    try {
      _liveChannel = client
          .channel('app_notifications_live')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'app_notifications',
            callback: (payload) {
              unawaited(
                initialize().then((_) => _showIfNew(payload.newRecord)),
              );
            },
          )
          .subscribe();
      AppLogger.info('Avisos em tempo real ativados.', tag: 'NOTIFY');
    } catch (error) {
      AppLogger.warn(
        'Realtime de avisos indisponível (${error.runtimeType}).',
        tag: 'NOTIFY',
      );
    }
  }

  static Future<void> _showIfNew(Map<String, dynamic> row) async {
    if (!_initialized) return;
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_lastSeenKey) == id) return;

    await _presenter.show(
      id: id,
      title: row['title']?.toString() ?? 'CiNey',
      body: row['body']?.toString() ?? '',
    );
    await prefs.setInt(_lastSeenKey, id);
    AppLogger.info('Aviso $id exibido ao usuário.', tag: 'NOTIFY');
  }
}
