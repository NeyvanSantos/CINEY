import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_logger.dart';

/// Notificações de aviso escritas pelo administrador no Supabase.
///
/// A tabela `app_notifications` é consultada na abertura do app; quando há
/// uma mensagem ativa ainda não vista pelo aparelho, ela é exibida como
/// notificação do sistema Android e marcada como lida localmente.
class AppNotifications {
  AppNotifications._();

  static const _channelId = 'ciney_announcements';
  static const _channelName = 'Avisos CiNey';
  static const _channelDescription =
      'Mensagens e novidades enviadas pela equipe CiNey';
  static const _lastSeenKey = 'last_seen_notification_id';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Prepara o canal e solicita a permissão de notificações (Android 13+).
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(settings);

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
      await android?.requestNotificationsPermission();
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

      final id = (row['id'] as num).toInt();
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt(_lastSeenKey) == id) return;

      await _plugin.show(
        id,
        row['title']?.toString() ?? 'CiNey',
        row['body']?.toString() ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      await prefs.setInt(_lastSeenKey, id);
      AppLogger.info('Aviso $id exibido ao usuário.', tag: 'NOTIFY');
    } catch (error) {
      AppLogger.warn(
        'Falha ao verificar avisos (${error.runtimeType}).',
        tag: 'NOTIFY',
      );
    }
  }
}
