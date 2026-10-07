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
    );

    expect(await repository.load(), isEmpty);
  });

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
