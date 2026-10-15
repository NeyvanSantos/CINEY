import 'dart:async';

import 'package:ciney_core/core/routes/app_router.dart';
import 'package:ciney_core/core/services/app_logger.dart';
import 'package:ciney_core/features/auth/services/account_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mobile_announcements.dart';
import 'notification_policy.dart';

@pragma('vm:entry-point')
Future<void> cineyBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Notification payloads are displayed by Android while the app is closed.
}

class MobilePushService extends ChangeNotifier {
  MobilePushService._();
  static final instance = MobilePushService._();
  SupabaseClient? _client;
  FirebaseMessaging? _messaging;
  Future<void>? _starting;
  Future<void> _registration = Future.value();
  String? _registeredUser;
  String? _token;
  String? pendingRoute;
  bool _signingOut = false;
  bool _requestingRegistration = false;
  int _revision = 0;

  Future<void> start(SupabaseClient client) => _starting ??= _start(client);

  Future<void> _start(SupabaseClient client) async {
    _client = client;
    MobileAnnouncements.instance.onTap = open;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(cineyBackgroundMessage);
      _messaging = FirebaseMessaging.instance;
      await MobileAnnouncements.instance.initialize();
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => open(message.data),
      );
      FirebaseMessaging.onMessage.listen((message) async {
        try {
          if (client.auth.currentUser == null || _signingOut) return;
          final prefs = await loadPreferences();
          if (prefs['enabled'] != true || message.notification == null) return;
          await MobileAnnouncements.instance.showPush(
            id:
                (message.messageId ?? message.data.toString()).hashCode &
                0x7fffffff,
            title: message.notification!.title ?? 'CiNey',
            body: message.notification!.body ?? '',
            data: message.data,
            tag: message.notification?.android?.tag,
          );
        } catch (_) {
          _warn();
        }
      });
      _messaging!.onRegistered.listen((id) {
        if (!_requestingRegistration && !_signingOut && id != _token) {
          unawaited(register());
        }
      }, onError: (_) => _warn());
      client.auth.onAuthStateChange.listen((event) {
        if (event.event == AuthChangeEvent.signedOut) {
          _revision++;
          _registeredUser = null;
          _token = null;
          _signingOut = false;
          _registration = _registration
              .then((_) => _unregister())
              .catchError((_) => _warn());
          unawaited(MobileAnnouncements.instance.plugin.cancelAll());
        } else if (!_signingOut) {
          unawaited(register());
        }
        notifyListeners();
      });
      try {
        final initial = await _messaging!.getInitialMessage();
        if (initial != null) open(initial.data);
      } catch (_) {
        _warn();
      }
      await register();
    } catch (_) {
      _warn(); // Push outages must not prevent catalog/login/playback.
      _starting = null;
    }
  }

  static void _warn() => AppLogger.warn(
    'Notificações temporariamente indisponíveis.',
    tag: 'NOTIFICATIONS',
  );

  void open(Map<String, dynamic> data) {
    pendingRoute = notificationRoute(data);
    notifyListeners();
  }

  Future<Map<String, bool>> loadPreferences() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) throw StateError('Entre na sua conta.');
    final row = await client
        .from('notification_preferences')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    return notificationPreferences(row);
  }

  Future<void> savePreference(String key, bool value) async {
    if (!notificationPreferenceLabels.containsKey(key)) return;
    final client = _client!;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Entre na sua conta.');
    await client.from('notification_preferences').upsert({
      'user_id': user.id,
      key: value,
    });
    if (key == 'enabled') {
      if (value) {
        await register(requestPermission: true);
      } else {
        await MobileAnnouncements.instance.plugin.cancelAll();
      }
    }
  }

  Future<bool> permissionGranted({bool request = false}) async {
    if (_messaging == null) return false;
    final settings = request
        ? await _messaging!.requestPermission()
        : await _messaging!.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> register({bool requestPermission = false}) {
    final revision = _revision;
    final task = _registration.then<void>((_) async {
      final client = _client;
      final user = client?.auth.currentUser;
      if (client == null ||
          user == null ||
          _messaging == null ||
          _signingOut ||
          revision != _revision) {
        return;
      }
      if (!await permissionGranted(request: requestPermission)) return;
      final local = await SharedPreferences.getInstance();
      if (_signingOut ||
          revision != _revision ||
          client.auth.currentUser?.id != user.id) {
        return;
      }
      final previousUser = local.getString('push_token_owner');
      if (previousUser != null && previousUser != user.id) {
        await _unregister();
        // A new FID prevents cross-account reuse even after offline logout.
        await FirebaseInstallations.instance.delete();
      }
      _requestingRegistration = true;
      late final String token;
      try {
        final registered = _messaging!.onRegistered.first.timeout(
          const Duration(seconds: 20),
        );
        final results = await Future.wait<Object?>([
          _messaging!
              .register()
              .timeout(const Duration(seconds: 20))
              .then<Object?>((_) => null),
          registered,
        ]);
        token = results[1] as String;
      } finally {
        _requestingRegistration = false;
      }
      if (revision != _revision ||
          _signingOut ||
          client.auth.currentUser?.id != user.id) {
        return;
      }
      final row = await client
          .from('notification_preferences')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();
      if (row == null) {
        await client
            .from('notification_preferences')
            .upsert(
              {'user_id': user.id},
              onConflict: 'user_id',
              ignoreDuplicates: true,
            );
      }
      if (revision != _revision ||
          _signingOut ||
          client.auth.currentUser?.id != user.id) {
        return;
      }
      await client.from('notification_devices').upsert({
        'user_id': user.id,
        'token': token,
      }, onConflict: 'token');
      await local.setString('push_token_owner', user.id);
      if (revision == _revision && !_signingOut) {
        _registeredUser = user.id;
        _token = token;
      }
    });
    _registration = task.catchError((_) => _warn());
    return _registration;
  }

  Future<void> beforeSignOut() async {
    _signingOut = true;
    _revision++;
    try {
      try {
        await _registration.timeout(const Duration(seconds: 25));
      } catch (_) {
        _warn();
      }
      final userId = _client?.auth.currentUser?.id;
      if (userId != null && _token != null) {
        try {
          await _client!
              .from('notification_devices')
              .delete()
              .eq('user_id', userId)
              .eq('token', _token!)
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          _warn();
        }
      }
      try {
        await _unregister().timeout(const Duration(seconds: 5));
      } catch (_) {
        _warn();
      }
      await MobileAnnouncements.instance.plugin.cancelAll();
    } catch (_) {
      _warn();
    } finally {
      _registeredUser = null;
      _token = null;
      pendingRoute = null;
      // Cleared by signedOut; registration cannot race the pending logout.
    }
  }

  Future<void> _unregister() async {
    await _messaging?.unregister();
  }

  Future<void> sendTest() async {
    await register(requestPermission: true);
    if (_token == null || _registeredUser != _client?.auth.currentUser?.id) {
      throw StateError('Ative a permissão de notificações e tente novamente.');
    }
    final result = await _client!.functions.invoke(
      'notification-self-test',
      body: {'token': _token},
    );
    if (result.status != 200 ||
        result.data is! Map ||
        result.data['sent'] != true) {
      throw StateError(
        'Não foi possível enviar o aviso. Tente novamente em um minuto.',
      );
    }
  }
}

class MobilePushHost extends ConsumerStatefulWidget {
  const MobilePushHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<MobilePushHost> createState() => _MobilePushHostState();
}

class _MobilePushHostState extends ConsumerState<MobilePushHost>
    with WidgetsBindingObserver {
  final push = MobilePushService.instance;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    push.addListener(_openPending);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _router = ref.read(appRouterProvider(false));
      _router!.routerDelegate.addListener(_openPending);
      final client = ref.read(supabaseClientProvider);
      if (client != null) unawaited(push.start(client));
    });
  }

  void _openPending() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || push.pendingRoute == null || _router == null) return;
      final client = ref.read(supabaseClientProvider);
      final path = _router!.routeInformationProvider.value.uri.path;
      // Preserve the destination while login/onboarding completes normally.
      if (client?.auth.currentUser == null ||
          ['/splash', '/auth', '/onboarding'].contains(path)) {
        return;
      }
      final route = push.pendingRoute!;
      push.pendingRoute = null;
      _router!.go(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final client = ref.read(supabaseClientProvider);
      if (client != null) {
        unawaited(push.start(client).then((_) => push.register()));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    push.removeListener(_openPending);
    _router?.routerDelegate.removeListener(_openPending);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
