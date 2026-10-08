import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/account_config.dart';
import 'features/auth/services/account_repository.dart';
import 'features/auth/services/secure_session_storage.dart';
import 'core/config/app_environment.dart';
import 'core/config/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/services/app_logger.dart';

Future<void> runCinemaxApp({bool isTv = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment.isTv = isTv;
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLogger.error(
      details.exceptionAsString(),
      tag: 'FLUTTER',
      stackTrace: details.stack,
    );
    previousFlutterError?.call(details);
  };
  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  final previousPlatformError = dispatcher.onError;
  dispatcher.onError = (error, stack) {
    AppLogger.error('$error', tag: 'ASYNC', stackTrace: stack);
    return previousPlatformError?.call(error, stack) ?? false;
  };
  AppLogger.info('Aplicativo iniciado.', tag: 'SYSTEM');

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D0D22),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  SupabaseClient? accountClient;
  const config = AccountConfig.environment;
  if (config.isConfigured) {
    try {
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.publicKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          detectSessionInUri: false,
          localStorage: SecureSessionStorage(
            'ciney-session-${Uri.parse(config.url).host}',
          ),
        ),
      );
      accountClient = Supabase.instance.client;
    } catch (error) {
      AppLogger.warn(
        'Contas indisponíveis na inicialização (${error.runtimeType}).',
        tag: 'ACCOUNT',
      );
    }
  }
  runApp(
    ProviderScope(
      overrides: [supabaseClientProvider.overrideWithValue(accountClient)],
      child: CinemaxApp(isTv: isTv),
    ),
  );
}

class CinemaxApp extends ConsumerWidget {
  const CinemaxApp({super.key, this.isTv = false});

  final bool isTv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CiNey',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: ref.watch(appRouterProvider(isTv)),
    );
  }
}
