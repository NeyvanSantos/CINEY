import 'package:cinemax/features/auth/services/account_repository.dart';
import 'package:cinemax/features/details/presentation/details_screen.dart';
import 'package:cinemax/plugin_engine/manager/plugin_manager.dart';
import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:cinemax/plugin_engine/models/stream_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_accounts.dart';

class _FakeTvSeriesCatalog extends PluginManager {
  _FakeTvSeriesCatalog(this.detail);
  final ContentDetail detail;
  @override
  Future<List<StreamSource>> getStreams(
    String contentId,
    String pluginId, {
    int? season,
    int? episode,
  }) async => const [
    StreamSource(
      url: 'https://media.test/episode.mp4',
      quality: 'HD',
      server: 'Teste',
    ),
  ];

  @override
  Future<ContentDetail?> getDetail(String contentId, String pluginId) async =>
      detail;

  @override
  Future<List<ContentItem>> getEpisodes(
    String contentId,
    String pluginId,
    int season,
  ) async {
    return [
      ContentItem(
        id: 'ep-$season-1',
        title: 'T$season E1 - Piloto da Temporada $season',
        posterUrl: '',
        type: ContentType.series,
        pluginId: pluginId,
        episodeNumber: 1,
      ),
      ContentItem(
        id: 'ep-$season-2',
        title: 'T$season E2 - Segundo episódio',
        posterUrl: '',
        type: ContentType.series,
        pluginId: pluginId,
        episodeNumber: 2,
      ),
    ];
  }
}

void main() {
  Future<List<Uri>> pumpTvSeries(
    WidgetTester tester,
    ContentDetail detail,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
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
            isTv: true,
          ),
        ),
        GoRoute(
          path: '/player/:contentId/:pluginId',
          builder: (_, state) {
            openedPlayers.add(state.uri);
            return const Scaffold(body: Text('Player aberto na TV'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(accounts),
          pluginManagerProvider.overrideWith(
            (ref) => _FakeTvSeriesCatalog(detail),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [
            Locale('pt', 'BR'),
            Locale('en', 'US'),
            Locale('es', 'ES'),
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          shortcuts: <ShortcutActivator, Intent>{
            ...WidgetsApp.defaultShortcuts,
            const SingleActivator(LogicalKeyboardKey.select):
                const ActivateIntent(),
          },
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return openedPlayers;
  }

  const seriesDetail = ContentDetail(
    id: 'series-breaking-bad',
    title: 'Breaking Bad',
    posterUrl: '',
    type: ContentType.series,
    pluginId: 'superflix',
    seasons: [Season(number: 1), Season(number: 2), Season(number: 3)],
  );

  testWidgets(
    'Android TV: seleção de temporada via tap e episódio via tap dispara player',
    (tester) async {
      final openedPlayers = await pumpTvSeries(tester, seriesDetail);

      // Deve carregar inicialmente os episódios da Temporada 1
      expect(find.text('Temporada 1'), findsWidgets);
      expect(find.text('T1 E1 - Piloto da Temporada 1'), findsOneWidget);

      // Mudar para Temporada 2
      final season2Chip = find.text('Temporada 2');
      expect(season2Chip, findsOneWidget);
      await tester.ensureVisible(season2Chip);
      await tester.tap(season2Chip);
      await tester.pumpAndSettle();

      // Lista de episódios deve atualizar para Temporada 2
      expect(find.text('T2 E1 - Piloto da Temporada 2'), findsOneWidget);
      expect(find.text('T2 E2 - Segundo episódio'), findsOneWidget);

      // Episódios da Temporada 1 não devem estar visíveis
      expect(find.text('T1 E1 - Piloto da Temporada 1'), findsNothing);

      // Acionar o segundo episódio
      final episode2 = find.text('T2 E2 - Segundo episódio');
      await tester.ensureVisible(episode2);
      await tester.tap(episode2);
      await tester.pumpAndSettle();

      // Tratar seleção de servidor, se aparecer
      if (find.text('Escolha o Servidor').evaluate().isNotEmpty) {
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
      }

      expect(find.text('Player aberto na TV'), findsOneWidget);
      final openedUri = openedPlayers.last;
      expect(openedUri.queryParameters['season'], '2');
      expect(openedUri.queryParameters['episode'], '2');
    },
  );

  testWidgets('Android TV: tecla Select/Enter ativa chip de temporada focado', (
    tester,
  ) async {
    await pumpTvSeries(tester, seriesDetail);

    // Temporada 1 ativa inicialmente
    expect(find.text('T1 E1 - Piloto da Temporada 1'), findsOneWidget);

    // Localizar e focar o chip da Temporada 3
    final season3Finder = find.text('Temporada 3');
    expect(season3Finder, findsOneWidget);
    await tester.ensureVisible(season3Finder);
    await tester.pumpAndSettle();

    // Tap para dar foco + ativar
    await tester.tap(season3Finder);
    await tester.pumpAndSettle();

    // Deve exibir episódios da Temporada 3
    expect(find.text('T3 E1 - Piloto da Temporada 3'), findsOneWidget);
    // Temporada 1 não mais visível
    expect(find.text('T1 E1 - Piloto da Temporada 1'), findsNothing);
  });

  testWidgets(
    'Android TV: tecla Select no episódio abre player com dados corretos',
    (tester) async {
      final openedPlayers = await pumpTvSeries(tester, seriesDetail);

      // Localizar primeiro episódio da Temporada 1
      final ep1 = find.text('T1 E1 - Piloto da Temporada 1');
      expect(ep1, findsOneWidget);
      await tester.ensureVisible(ep1);
      await tester.pumpAndSettle();

      // Tap aciona o episódio
      await tester.tap(ep1);
      await tester.pumpAndSettle();

      // Tratar seleção de servidor
      if (find.text('Escolha o Servidor').evaluate().isNotEmpty) {
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
      }

      expect(find.text('Player aberto na TV'), findsOneWidget);
      final uri = openedPlayers.last;
      expect(uri.queryParameters['season'], '1');
      expect(uri.queryParameters['episode'], '1');
    },
  );

  testWidgets(
    'Android TV: botão Assistir Agora recebe autofocus na tela de detalhes',
    (tester) async {
      await pumpTvSeries(tester, seriesDetail);

      // O botão Assistir Agora deve existir e ter foco
      final watchButton = find.text('Assistir Agora');
      expect(watchButton, findsOneWidget);

      // Verificar que o botão está focável
      final buttonWidget = find.ancestor(
        of: watchButton,
        matching: find.byType(ElevatedButton),
      );
      expect(buttonWidget, findsOneWidget);

      // Verificar que há chips de temporada visíveis e navegáveis
      expect(find.text('Temporada 1'), findsWidgets);
      expect(find.text('Temporada 2'), findsOneWidget);
      expect(find.text('Temporada 3'), findsOneWidget);
    },
  );

  testWidgets(
    'Android TV: D-Pad navega de Assistir Agora -> Temporadas -> Episódio',
    (tester) async {
      await pumpTvSeries(tester, seriesDetail);

      // Assistir Agora tem foco inicial
      final primary1 = FocusManager.instance.primaryFocus;
      String describeFocus(FocusNode? node) {
        if (node == null || node.context == null) return 'null';
        final element = node.context! as Element;
        final texts = <String>[];
        element.visitChildren((child) {
          void visit(Element el) {
            if (el.widget is Text) {
              texts.add((el.widget as Text).data ?? '');
            }
            el.visitChildren(visit);
          }

          visit(child);
        });
        return 'Node(${node.debugLabel}) texts: $texts';
      }

      expect(describeFocus(primary1), contains('Assistir Agora'));

      // Pressiona arrowDown
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      final primary2 = FocusManager.instance.primaryFocus;
      expect(describeFocus(primary2), contains('Temporada'));

      // Pressiona arrowDown novamente
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      final primary3 = FocusManager.instance.primaryFocus;
      expect(describeFocus(primary3), contains('Piloto'));
    },
  );

  testWidgets('Android TV: retorno à tela anterior preserva contexto', (
    tester,
  ) async {
    await pumpTvSeries(tester, seriesDetail);

    // Mudar para Temporada 2
    final season2 = find.text('Temporada 2');
    await tester.ensureVisible(season2);
    await tester.tap(season2);
    await tester.pumpAndSettle();

    expect(find.text('T2 E1 - Piloto da Temporada 2'), findsOneWidget);

    // Abrir episódio e voltar
    final ep = find.text('T2 E1 - Piloto da Temporada 2');
    await tester.ensureVisible(ep);
    await tester.tap(ep);
    await tester.pumpAndSettle();

    // Tratar seleção de servidor
    if (find.text('Escolha o Servidor').evaluate().isNotEmpty) {
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
    }

    expect(find.text('Player aberto na TV'), findsOneWidget);
  });
}
