import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  runApp(ProviderScope(child: CinemaxApp(isTv: isTv)));
}

class CinemaxApp extends StatelessWidget {
  CinemaxApp({super.key, this.isTv = false});

  final bool isTv;
  late final _router = createAppRouter(isTv: isTv);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CiNey',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
