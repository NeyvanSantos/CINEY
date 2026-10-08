import 'dart:convert';

import 'package:cinemax/features/player/services/watch_history_repository.dart';
import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late WatchHistoryRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = WatchHistoryRepository();
  });

  const item = ContentItem(
    id: 'series-1',
    title: 'Série de teste',
    posterUrl: 'https://example.com/poster.jpg',
    type: ContentType.series,
    pluginId: 'test-plugin',
  );

  test('salva metadados e progresso por episódio', () async {
    await repository.markStarted(item, season: 2, episode: 3);
    await repository.saveProgress(
      item,
      season: 2,
      episode: 3,
      position: const Duration(minutes: 12),
      duration: const Duration(minutes: 40),
    );

    final entries = await repository.load();
    expect(entries, hasLength(1));
    expect(entries.single.item.title, 'Série de teste');
    expect(entries.single.season, 2);
    expect(entries.single.episode, 3);
    expect(entries.single.position, const Duration(minutes: 12));
    expect(entries.single.progress, 0.3);
  });

  test('remove conteúdo concluído do histórico', () async {
    await repository.markStarted(item);
    await repository.saveProgress(
      item,
      position: const Duration(minutes: 39),
      duration: const Duration(minutes: 40),
      completed: true,
    );

    expect(await repository.load(), isEmpty);
  });

  test(
    'servidor persiste ao reabrir e ao atualizar progresso sem nova escolha',
    () async {
      await repository.saveProgress(
        item,
        position: const Duration(milliseconds: 123456),
        duration: const Duration(minutes: 40),
        server: 'EmbedMovies',
      );
      repository = WatchHistoryRepository();
      await repository.markStarted(item);
      await repository.saveProgress(
        item,
        position: const Duration(milliseconds: 234567),
        duration: const Duration(minutes: 40),
      );
      final saved = await repository.findProgress(item);
      expect(saved?.server, 'EmbedMovies');
      expect(saved?.position.inMilliseconds, 234567);
    },
  );

  test('trocar servidor atualiza apenas o episódio assistido', () async {
    for (final episode in [1, 2]) {
      await repository.markStarted(
        item,
        season: 1,
        episode: episode,
        server: 'SuperFlix',
      );
    }
    await repository.saveProgress(
      item,
      season: 1,
      episode: 2,
      position: const Duration(seconds: 10),
      duration: const Duration(minutes: 40),
      server: 'EmbedMovies',
    );
    expect(
      (await repository.findProgress(item, season: 1, episode: 1))?.server,
      'SuperFlix',
    );
    expect(
      (await repository.findProgress(item, season: 1, episode: 2))?.server,
      'EmbedMovies',
    );
  });

  test(
    'histórico antigo sem servidor continua legível e preserva o tempo',
    () async {
      await repository.saveProgress(
        item,
        position: const Duration(milliseconds: 123456),
        duration: const Duration(minutes: 40),
      );
      final preferences = await SharedPreferences.getInstance();
      final data =
          jsonDecode(preferences.getString('watch-history-v1')!) as List;
      (data.single as Map).remove('server');
      await preferences.setString('watch-history-v1', jsonEncode(data));
      final restored = await WatchHistoryRepository().findProgress(item);
      expect(restored?.server, isNull);
      expect(restored?.position.inMilliseconds, 123456);
    },
  );

  test(
    'preserva milissegundos e ponto de parada mesmo depois de 95 por cento',
    () async {
      const position = Duration(milliseconds: 2376123);
      await repository.saveProgress(
        item,
        position: position,
        duration: const Duration(minutes: 40),
      );
      final restored = await WatchHistoryRepository().findProgress(item);
      expect(restored?.position, position);
      await repository.markStarted(item);
      expect((await repository.findProgress(item))?.position, position);
    },
  );

  test(
    'salva paradas nos primeiros segundos e rebobinar para o início',
    () async {
      await repository.saveProgress(
        item,
        position: const Duration(milliseconds: 2456),
        duration: const Duration(minutes: 40),
      );
      expect(
        (await repository.findProgress(item))?.position.inMilliseconds,
        2456,
      );
      await repository.saveProgress(
        item,
        position: Duration.zero,
        duration: const Duration(minutes: 40),
      );
      expect((await repository.findProgress(item))?.position, Duration.zero);
    },
  );

  test('mantém filme e série com IDs iguais separados', () async {
    const movie = ContentItem(
      id: 'same-id',
      title: 'Filme',
      posterUrl: '',
      type: ContentType.movie,
      pluginId: 'test-plugin',
    );
    const series = ContentItem(
      id: 'same-id',
      title: 'Série',
      posterUrl: '',
      type: ContentType.series,
      pluginId: 'test-plugin',
    );

    await repository.markStarted(movie);
    await repository.markStarted(series);

    expect(await repository.load(), hasLength(2));
  });
}
