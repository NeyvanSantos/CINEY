import 'dart:async';

import 'package:cinemax/features/player/presentation/player_screen.dart';
import 'package:cinemax/features/player/services/watch_history_repository.dart';
import 'package:cinemax/plugin_engine/manager/plugin_manager.dart';
import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:cinemax/plugin_engine/models/stream_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _Catalog extends PluginManager {
  final opened = <(int?, int?)>[];
  bool failEpisodes = false;

  @override
  Future<List<StreamSource>> getStreams(
    String contentId,
    String pluginId, {
    int? season,
    int? episode,
  }) async {
    opened.add((season, episode));
    return [
      StreamSource(
        url: 'https://video.test/$season/$episode.mp4',
        quality: 'HD',
        server: 'Teste',
        isEmbed: false,
      ),
    ];
  }

  @override
  Future<List<ContentItem>> getEpisodes(
    String contentId,
    String pluginId,
    int season,
  ) async {
    if (failEpisodes) throw StateError('Catálogo indisponível');
    return [
      for (var number = 1; number <= (season == 1 ? 2 : 1); number++)
        ContentItem(
          id: '$season-$number',
          title: 'Episódio $number',
          posterUrl: '',
          type: ContentType.series,
          pluginId: pluginId,
          episodeNumber: number,
        ),
    ];
  }

  @override
  Future<ContentDetail?> getDetail(String contentId, String pluginId) async =>
      ContentDetail(
        id: contentId,
        title: 'Série',
        posterUrl: '',
        type: ContentType.series,
        pluginId: pluginId,
        seasons: const [Season(number: 1), Season(number: 2)],
      );
}

class _VideoPlatform extends VideoPlayerPlatform {
  final streams = <int, StreamController<VideoEvent>>{};
  final positions = <int, Duration>{};
  final seeks = <(int, Duration)>[];
  int nextId = 0;

  @override
  Future<void> init() async {}
  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    final id = nextId++;
    streams[id] = StreamController<VideoEvent>()
      ..add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(minutes: 20),
          size: const Size(1920, 1080),
        ),
      );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;
  @override
  Future<Duration> getPosition(int playerId) async =>
      positions[playerId] ?? Duration.zero;
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seeks.add((playerId, position));
    positions[playerId] = position;
  }

  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> dispose(int playerId) async {
    await streams[playerId]?.close();
  }

  @override
  Widget buildView(int playerId) => const SizedBox.expand();

  void complete(int id) =>
      streams[id]!.add(VideoEvent(eventType: VideoEventType.completed));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _VideoPlatform platform;
  late _Catalog catalog;
  late VideoPlayerPlatform previous;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = VideoPlayerPlatform.instance;
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
    catalog = _Catalog();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/wakelock'),
          (_) async => null,
        );
  });
  tearDown(() {
    VideoPlayerPlatform.instance = previous;
  });

  Future<void> pumpPlayer(
    WidgetTester tester, {
    int episode = 1,
    bool isTv = false,
    bool movie = false,
    int resumePositionMs = 60000,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pluginManagerProvider.overrideWith((ref) => catalog)],
        child: MaterialApp(
          home: PlayerScreen(
            contentId: movie ? 'test-film' : 'test-series',
            pluginId: 'test',
            title: 'Série • Episódio $episode',
            contentTitle: 'Série',
            mediaType: movie ? 'movie' : 'series',
            season: movie ? null : 1,
            episode: movie ? null : episode,
            resumePositionMs: resumePositionMs,
            isTv: isTv,
          ),
        ),
      ),
    );
    for (var n = 0; n < 8; n++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> finish(WidgetTester tester, int id) async {
    platform.complete(id);
    for (var n = 0; n < 8; n++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets(
    'terminar avança uma vez, zera retomada e registra o próximo episódio',
    (tester) async {
      await pumpPlayer(tester);
      expect(catalog.opened, [(1, 1)]);
      expect(find.text('Próximo episódio'), findsOneWidget);
      await finish(tester, 0);
      expect(catalog.opened, [(1, 1), (1, 2)]);
      expect(platform.seeks.where((seek) => seek.$1 == 1), isEmpty);
      final entries = await WatchHistoryRepository().load();
      expect(entries.single.episode, 2);
      expect(entries.single.position, Duration.zero);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('TV avança para outra temporada e para no fim da série', (
    tester,
  ) async {
    await pumpPlayer(tester, episode: 2, isTv: true);
    await finish(tester, 0);
    expect(catalog.opened, [(1, 2), (2, 1)]);
    await finish(tester, 1);
    expect(catalog.opened, [(1, 2), (2, 1)]);
    expect(find.text('Próximo episódio'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('preferência desativada mantém avanço manual dentro do player', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'playback-auto-next-episode': false,
    });
    await pumpPlayer(tester);
    await finish(tester, 0);
    expect(catalog.opened, [(1, 1)]);
    await tester.tap(find.text('Próximo episódio'));
    for (var n = 0; n < 8; n++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(catalog.opened, [(1, 1), (1, 2)]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('avanço manual preserva o tempo do episódio anterior', (
    tester,
  ) async {
    await pumpPlayer(tester);
    platform.positions[0] = const Duration(minutes: 7);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Próximo episódio'));
    for (var n = 0; n < 8; n++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final entries = await WatchHistoryRepository().load();
    expect(entries.first.episode, 2);
    expect(entries.first.position, Duration.zero);
    expect(entries.last.episode, 1);
    expect(entries.last.position, const Duration(minutes: 7));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  const film = ContentItem(
    id: 'test-film',
    title: 'Filme',
    posterUrl: '',
    type: ContentType.movie,
    pluginId: 'test',
  );

  testWidgets(
    'filme aberto sem parâmetro de retomada usa milissegundos salvos',
    (tester) async {
      await WatchHistoryRepository().saveProgress(
        film,
        position: const Duration(milliseconds: 321987),
        duration: const Duration(minutes: 20),
      );
      await pumpPlayer(tester, movie: true, resumePositionMs: 0);
      expect(platform.seeks.first.$2, const Duration(milliseconds: 321987));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'filme retoma perto dos créditos e prefere histórico atual à rota antiga',
    (tester) async {
      await WatchHistoryRepository().saveProgress(
        film,
        position: const Duration(milliseconds: 1190123),
        duration: const Duration(minutes: 20),
      );
      await pumpPlayer(tester, movie: true, resumePositionMs: 60000);
      expect(platform.seeks.first.$2, const Duration(milliseconds: 1190123));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('preferência de retomada desligada inicia o filme do começo', (
    tester,
  ) async {
    await WatchHistoryRepository().saveProgress(
      film,
      position: const Duration(milliseconds: 321987),
      duration: const Duration(minutes: 20),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('playback-resume-enabled', false);
    await pumpPlayer(tester, movie: true);
    expect(platform.seeks, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'sair consulta ponto atual e termina a escrita antes de voltar ao catálogo',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [pluginManagerProvider.overrideWith((ref) => catalog)],
          child: MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('Catálogo')),
          ),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const PlayerScreen(
              contentId: 'test-film',
              pluginId: 'test',
              title: 'Filme',
            ),
          ),
        ),
      );
      for (var n = 0; n < 8; n++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      // Change the platform time without giving the player's polling timer a tick.
      platform.positions[0] = const Duration(milliseconds: 987654);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      for (var n = 0; n < 4; n++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Catálogo'), findsOneWidget);
      final saved = await WatchHistoryRepository().findProgress(film);
      expect(saved?.position, const Duration(milliseconds: 987654));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('trocar de aplicativo salva o tempo atual antes de suspender', (
    tester,
  ) async {
    await pumpPlayer(tester, movie: true, resumePositionMs: 0);
    platform.positions[0] = const Duration(milliseconds: 456789);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    for (var n = 0; n < 3; n++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      (await WatchHistoryRepository().findProgress(film))?.position,
      const Duration(milliseconds: 456789),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('falha de catálogo permite tentar novamente sem sair do player', (
    tester,
  ) async {
    catalog.failEpisodes = true;
    await pumpPlayer(tester);
    expect(catalog.opened, [(1, 1)]);
    expect(find.text('Recarregar episódios'), findsOneWidget);
    catalog.failEpisodes = false;
    await tester.tap(find.text('Recarregar episódios'));
    for (var n = 0; n < 8; n++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(catalog.opened, [(1, 1), (1, 2)]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
