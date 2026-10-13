import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:cinemax/plugin_engine/runtime/tmdb_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'carrega episódios TMDB sem depender do plugin que exibiu a série',
    () async {
      final client = Dio(BaseOptions(baseUrl: 'https://tmdb.test/3'));
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/tv/58981/season/1');
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'episodes': [
                    {
                      'episode_number': 2,
                      'name': 'Segundo episódio',
                      'overview': 'A segunda aventura.',
                      'air_date': '2013-10-21',
                      'vote_average': 7.25,
                      'still_path': '/second.jpg',
                    },
                    {
                      'episode_number': 1,
                      'name': 'Piloto',
                      'overview': 'O começo da série.',
                      'air_date': '2013-10-14',
                      'vote_average': 8.0,
                      'still_path': '/first.jpg',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final episodes = await TmdbService.getEpisodes(
        'tmdb_58981_series',
        1,
        pluginId: 'com.megaflix',
        client: client,
      );

      expect(episodes, hasLength(2));
      expect(episodes.first.title, 'Episódio 1 — Piloto');
      expect(episodes.first.episodeNumber, 1);
      expect(episodes.first.type, ContentType.series);
      expect(episodes.first.pluginId, 'com.megaflix');
      expect(episodes.first.posterUrl, endsWith('/first.jpg'));
      expect(episodes.last.episodeNumber, 2);
    },
  );

  test('ignora IDs TMDB que não representam uma série', () async {
    final episodes = await TmdbService.getEpisodes(
      'tmdb_58981_movie',
      1,
      pluginId: 'com.megaflix',
    );

    expect(episodes, isEmpty);
  });
}
