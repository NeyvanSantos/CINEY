import 'package:cinemax/features/auth/services/account_repository.dart';
import 'package:cinemax/features/details/presentation/details_screen.dart';
import 'package:cinemax/plugin_engine/manager/plugin_manager.dart';
import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return openedPlayers;
  }

  for (final isTv in [false, true]) {
    testWidgets('Assistir Agora abre EmbedMovies diretamente (TV: $isTv)', (
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
      expect(find.text('Player aberto'), findsOneWidget);
      expect(find.text('Escolha o Servidor'), findsNothing);
      final uri = openedPlayers.last;
      expect(uri.path, '/player/tmdb_969681_movie/test');
      expect(uri.queryParameters['serverIndex'], '1');
    });
  }

  testWidgets('episódio escolhido mantém temporada e número ao abrir Embed', (
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
    expect(find.text('Player aberto'), findsOneWidget);
    final params = openedPlayers.last.queryParameters;
    expect(params['serverIndex'], '1');
    expect(params['season'], '2');
    expect(params['episode'], '3');
    expect(find.text('Escolha o Servidor'), findsNothing);
  });
}
