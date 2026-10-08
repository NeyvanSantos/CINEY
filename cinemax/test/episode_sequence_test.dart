import 'package:cinemax/features/player/services/episode_sequence.dart';
import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:cinemax/plugin_engine/runtime/stream_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

ContentItem episode(int number, {String? date}) => ContentItem(
  id: '$number',
  title: 'Episódio $number',
  posterUrl: '',
  type: ContentType.series,
  pluginId: 'test',
  episodeNumber: number,
  year: date,
);

void main() {
  EpisodeSequence sequence(
    Map<int, List<ContentItem>> catalog, {
    List<Season> seasons = const [Season(number: 1), Season(number: 2)],
  }) => EpisodeSequence(
    loadEpisodes: (season) async => catalog[season] ?? [],
    loadDetail: () async => ContentDetail(
      id: 'series',
      title: 'Série',
      posterUrl: '',
      type: ContentType.series,
      pluginId: 'test',
      seasons: seasons,
    ),
    now: () => DateTime(2026, 10, 8),
  );

  test(
    'segue números reais mesmo com episódios fora de ordem ou lacunas',
    () async {
      final next = await sequence({
        1: [episode(4), episode(1), episode(2)],
      }).next(1, 2);
      expect(next?.season, 1);
      expect(next?.number, 4);
      expect(next?.title, 'Episódio 4');
    },
  );

  test('atravessa temporadas sem entrar em especiais', () async {
    final next = await sequence(
      {
        0: [episode(1)],
        1: [episode(8)],
        2: [episode(1)],
      },
      seasons: const [Season(number: 2), Season(number: 0), Season(number: 1)],
    ).next(1, 8);
    expect(next?.season, 2);
    expect(next?.number, 1);
  });

  test('para no último episódio sem inventar outro número', () async {
    final next = await sequence({
      1: [episode(1)],
      2: [episode(1)],
    }).next(2, 1);
    expect(next, isNull);
  });

  test('não inicia episódios ou temporadas com lançamento futuro', () async {
    final next = await sequence({
      1: [episode(1, date: '2026-10-08'), episode(2, date: '2026-10-09')],
      2: [episode(1, date: '2027-01-01')],
    }).next(1, 1);
    expect(next, isNull);
  });

  test(
    'lista vazia ou sem o episódio atual não autoriza pular temporada',
    () async {
      expect(
        sequence({
          2: [episode(1)],
        }).next(1, 1),
        throwsStateError,
      );
      expect(
        sequence({
          1: [episode(1)],
          2: [episode(1)],
        }).next(1, 2),
        throwsStateError,
      );
    },
  );

  test(
    'catálogos sem números explícitos usam a mesma ordem da lista',
    () async {
      final next = await sequence({
        1: [
          const ContentItem(
            id: 'a',
            title: 'Primeiro',
            posterUrl: '',
            type: ContentType.anime,
            pluginId: 'test',
          ),
          const ContentItem(
            id: 'b',
            title: 'Segundo',
            posterUrl: '',
            type: ContentType.anime,
            pluginId: 'test',
          ),
        ],
      }).next(1, 1);
      expect(next?.number, 2);
      expect(next?.title, 'Segundo');
    },
  );

  test('séries locais usam o catálogo real do mesmo TMDB do servidor', () {
    expect(StreamResolverService.catalogIdFor('sc_5'), 'tmdb_1396_series');
    expect(StreamResolverService.catalogIdFor('ac_2'), 'tmdb_1429_series');
    expect(
      StreamResolverService.catalogIdFor('tmdb_123_series'),
      'tmdb_123_series',
    );
    expect(StreamResolverService.catalogIdFor('external'), 'external');
  });

  test(
    'falha na próxima temporada não permite saltar uma temporada inteira',
    () async {
      expect(
        sequence(
          {
            1: [episode(1)],
            3: [episode(1)],
          },
          seasons: const [
            Season(number: 1),
            Season(number: 2),
            Season(number: 3),
          ],
        ).next(1, 1),
        throwsStateError,
      );
    },
  );
}
