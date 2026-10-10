import 'package:cinemax/features/auth/services/account_repository.dart';
import 'package:cinemax/features/details/presentation/details_screen.dart';
import 'package:cinemax/plugin_engine/manager/plugin_manager.dart';
import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_accounts.dart';

class _Catalog extends PluginManager {
  _Catalog(this.detail);
  final ContentDetail detail;

  @override
  Future<ContentDetail?> getDetail(String contentId, String pluginId) async =>
      detail;

  @override
  Future<List<ContentItem>> getEpisodes(
    String contentId,
    String pluginId,
    int season,
  ) async => [
    ContentItem(
      id: 'episode-3',
      title: 'Terceiro episódio',
      posterUrl: '',
      type: ContentType.series,
      pluginId: pluginId,
      episodeNumber: 3,
    ),
  ];
}

void main() {
  Future<List<Uri>> pumpDetails(
    WidgetTester tester,
    ContentDetail detail, {
    bool isTv = false,
  }) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final accounts = FakeAccounts();
    addTearDown(accounts.changes.close);
    final openedPlayers = <Uri>[];
    final router = GoRouter(
      initialLocation: '/details',
      routes: [
        GoRoute(
          path: '/details',
          builder: (_, _) => DetailsScreen(
            contentId: detail.id,
            pluginId: detail.pluginId,
            initialDetail: detail,
            isTv: isTv,
          ),
        ),
        GoRoute(
          path: '/player/:contentId/:pluginId',
          builder: (_, state) {
            openedPlayers.add(state.uri);
            return const Scaffold(body: Text('Player aberto'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(accounts),
          pluginManagerProvider.overrideWith((ref) => _Catalog(detail)),
        ],
        child: MaterialApp.router(
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [
            Locale('pt', 'BR'),
            Locale('en', 'US'),
            Locale('es', 'ES'),
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return openedPlayers;
  }

  for (final isTv in [false, true]) {
    testWidgets('Assistir Agora seleciona a fonte correta (TV: $isTv)', (
      tester,
    ) async {
      final openedPlayers = await pumpDetails(
        tester,
        const ContentDetail(
          id: 'tmdb_969681_movie',
          title: 'Filme',
          posterUrl: '',
          type: ContentType.movie,
          pluginId: 'test',
        ),
        isTv: isTv,
      );
      await tester.tap(find.text('Assistir Agora'));
      await tester.pumpAndSettle();

      if (isTv) {
        expect(find.text('Escolha o Servidor'), findsOneWidget);
        expect(find.text('Player aberto'), findsNothing);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('server-option-0-selected')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.mouse_rounded), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        final cursorOpacity = find.ancestor(
          of: find.byIcon(Icons.mouse_rounded),
          matching: find.byType(AnimatedOpacity),
        );
        expect(tester.widget<AnimatedOpacity>(cursorOpacity).opacity, 0);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(find.text('Player aberto'), findsOneWidget);
        expect(openedPlayers.last.queryParameters['serverIndex'], '0');
        return;
      }

      expect(find.text('Escolha o Servidor'), findsOneWidget);
      expect(find.text('Player aberto'), findsNothing);
      await tester.tap(find.text('SuperFlix'));
      await tester.pumpAndSettle();
      expect(find.text('Player aberto'), findsOneWidget);
      final uri = openedPlayers.single;
      expect(uri.path, '/player/tmdb_969681_movie/test');
      expect(uri.queryParameters['serverIndex'], '0');
    });
  }

  testWidgets('episódio escolhido mantém dados ao selecionar servidor', (
    tester,
  ) async {
    final openedPlayers = await pumpDetails(
      tester,
      const ContentDetail(
        id: 'tmdb_1396_series',
        title: 'Série',
        posterUrl: '',
        type: ContentType.series,
        pluginId: 'test',
        seasons: [Season(number: 1), Season(number: 2)],
      ),
    );
    await tester.ensureVisible(find.text('Temporada 1'));
    await tester.tap(find.text('Temporada 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temporada 2').last);
    await tester.pumpAndSettle();
    final episode = find.textContaining('Terceiro episódio');
    await tester.ensureVisible(episode);
    await tester.tap(episode);
    await tester.pumpAndSettle();
    expect(find.text('Escolha o Servidor'), findsOneWidget);
    await tester.tap(find.text('SuperFlix'));
    await tester.pumpAndSettle();
    expect(find.text('Player aberto'), findsOneWidget);
    final params = openedPlayers.last.queryParameters;
    expect(params['serverIndex'], '0');
    expect(params['season'], '2');
    expect(params['episode'], '3');
    expect(find.text('Escolha o Servidor'), findsNothing);
  });
}
