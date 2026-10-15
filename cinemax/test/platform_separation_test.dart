import 'package:ciney_core/cinemax_app.dart';
import 'package:ciney_core/core/config/app_environment.dart';
import 'package:ciney_core/core/platform/app_platform_services.dart';
import 'package:ciney_core/core/routes/app_router.dart';
import 'package:ciney_core/core/services/in_app_announcements.dart';
import 'package:ciney_core/core/widgets/glass_card.dart';
import 'package:ciney_core/core/widgets/focusable_surface.dart';
import 'package:ciney_core/core/widgets/shimmer_loading.dart';
import 'package:ciney_core/features/auth/services/account_repository.dart';
import 'package:ciney_core/features/player/services/castlite_bridge_service.dart';
import 'package:ciney_core/plugin_engine/models/stream_source.dart';
import 'package:cinemax/mobile/mobile_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/fake_accounts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    AppPlatformServices.current = const AppPlatformServices();
    AppEnvironment.isTv = false;
  });
  tearDown(() {
    AppPlatformServices.current = const AppPlatformServices();
    AppEnvironment.isTv = false;
  });

  testWidgets('host sem envio não chama canais nativos de Cast', (
    tester,
  ) async {
    var nativeCalls = 0;
    const channel = MethodChannel('com.ciney/castlite');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      _,
    ) async {
      nativeCalls++;
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(
      await CastLiteBridgeService.launchCast(
        context: context,
        source: const StreamSource(
          url: 'https://media.example/video.mp4',
          quality: 'HD',
          server: 'Teste',
        ),
        title: 'Filme',
        posterUrl: '',
      ),
      false,
    );
    expect(nativeCalls, 0);
  });

  test('observador de frames é opcional no host TV', () async {
    expect(await AppFrameObserver.install(7, 'script'), false);
    await AppFrameObserver.remove(7);
  });

  test(
    'scanner existe só nas rotas mobile mesmo com adaptador disponível',
    () async {
      configureMobileServices();
      final accounts = FakeAccounts();
      final tv = createAppRouter(accounts: accounts, isTv: true);
      final mobile = createAppRouter(accounts: accounts);
      try {
        expect(
          tv.configuration.routes.whereType<GoRoute>().any(
            (route) => route.path == '/tv-pair-scan',
          ),
          false,
        );
        expect(
          mobile.configuration.routes.whereType<GoRoute>().any(
            (route) => route.path == '/tv-pair-scan',
          ),
          true,
        );
        expect(
          tv.configuration.routes.whereType<GoRoute>().any(
            (route) => route.path == '/tv-pair',
          ),
          true,
        );
      } finally {
        tv.dispose();
        mobile.dispose();
        await accounts.changes.close();
      }
    },
  );

  testWidgets('TV entrega aviso recebido antes da montagem, dentro do app', (
    tester,
  ) async {
    final presenter = InAppAnnouncementPresenter();
    await presenter.initialize();
    await presenter.show(id: 1, title: 'Aviso', body: 'Novos episódios');
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: presenter.messengerKey,
        home: const Scaffold(body: Text('Catálogo')),
      ),
    );
    presenter.flushAfterFrame();
    await tester.pump();
    expect(find.text('Aviso\nNovos episódios'), findsOneWidget);
  });

  testWidgets('cartão TV mantém a seleção sem desfoque nem animação contínua', (
    tester,
  ) async {
    AppEnvironment.isTv = true;
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GlassCard(
                onTap: () => opened = true,
                child: const Text('Abrir filme'),
              ),
              const ShimmerLoading(width: 120, height: 180),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.tap(find.text('Abrir filme'));
    expect(opened, true);
  });

  testWidgets('botão central do controle ativa superfícies nos diálogos TV', (
    tester,
  ) async {
    final accounts = FakeAccounts();
    late BuildContext pageContext;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) {
            pageContext = context;
            return const Scaffold(body: Text('TV'));
          },
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await accounts.changes.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider(true).overrideWithValue(router),
          accountRepositoryProvider.overrideWithValue(accounts),
        ],
        child: const CinemaxApp(isTv: true),
      ),
    );
    await tester.pumpAndSettle();
    final dismissed = showDialog<void>(
      context: pageContext,
      builder: (context) => AlertDialog(
        content: FocusableSurface(
          autofocus: true,
          onTap: () => Navigator.of(context).pop(),
          child: const Text('Depois'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Depois'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Depois'), findsNothing);
    expect(find.text('TV'), findsOneWidget);
    await dismissed;
  });
}
