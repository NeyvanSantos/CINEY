import 'package:cinemax/mobile/mobile_services.dart';
import 'package:castlite_engine/castlite_engine.dart';
import 'package:cinemax/features/auth/services/account_repository.dart';
import 'package:cinemax/features/details/presentation/details_screen.dart';
import 'package:cinemax/features/details/presentation/widgets/server_selection_sheet.dart';
import 'package:cinemax/plugin_engine/manager/plugin_manager.dart';
import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:cinemax/plugin_engine/models/stream_source.dart';
import 'package:cinemax/plugin_engine/runtime/stream_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_accounts.dart';

const _series = ContentDetail(
  id: 'tmdb_1_series',
  title: 'Série',
  posterUrl: '',
  type: ContentType.series,
  pluginId: 'test',
);

class _Catalog extends PluginManager {
  @override
  Future<ContentDetail?> getDetail(String contentId, String pluginId) async =>
      _series;

  @override
  Future<List<ContentItem>> getEpisodes(
    String contentId,
    String pluginId,
    int season,
  ) async => [
    ContentItem(
      id: 'ep9',
      title: 'Nono episódio',
      posterUrl: '',
      type: ContentType.series,
      pluginId: pluginId,
      episodeNumber: 9,
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final opened = <Map<Object?, Object?>>[];
  setUp(() {
    configureMobileServices();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CastLiteEngine.methods, (call) async {
          if (call.method == 'isAvailable') return true;
          if (call.method == 'open') {
            opened.add(Map<Object?, Object?>.from(call.arguments as Map));
          }
          return null;
        });
    opened.clear();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CastLiteEngine.methods, null);
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final accounts = FakeAccounts();
    addTearDown(accounts.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(accounts),
          pluginManagerProvider.overrideWith((ref) => _Catalog()),
        ],
        child: MaterialApp(
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'detalhes transmite o episódio escolhido, sem abrir player externo',
    (tester) async {
      await pump(
        tester,
        const DetailsScreen(
          contentId: 'tmdb_1_series',
          pluginId: 'test',
          initialDetail: _series,
        ),
      );
      final button = find.byKey(const ValueKey('cast-episode-9'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('server-option-0-idle')));
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(opened.single['season'], 1);
      expect(opened.single['episode'], 9);
      expect(opened.single['title'], 'Série - Nono episódio');
      final expected = StreamResolverService.resolveFromContentId(
        'tmdb_1_series',
        season: 1,
        episode: 9,
      );
      expect(
        (opened.single['sources'] as List).first['url'],
        expected.first.url,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'ação no servidor preserva lista e contexto do episódio',
    (tester) async {
      const sources = [
        StreamSource(
          url: 'https://media.example/a.mp4',
          quality: 'Auto',
          server: 'A',
        ),
        StreamSource(
          url: 'https://media.example/b.mp4',
          quality: 'Auto',
          server: 'B',
        ),
      ];
      await pump(
        tester,
        Scaffold(
          body: ServerSelectionSheet(
            item: _series,
            sources: sources,
            isTv: false,
            onSelect: (_) {},
            season: 2,
            episode: 9,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Transmitir este servidor para TV').last);
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(opened.single['sourceIndex'], 1);
      expect(opened.single['season'], 2);
      expect(opened.single['episode'], 9);
      expect(opened.single['sources'], hasLength(2));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
