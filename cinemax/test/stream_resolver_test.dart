import 'package:cinemax/plugin_engine/models/stream_source.dart';
import 'package:cinemax/plugin_engine/runtime/stream_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void expectSources(List<StreamSource> sources, List<String> urls) {
  expect(sources, hasLength(4));
  expect(sources.map((source) => source.server), [
    'SuperFlix',
    'WarezCDN',
    'EmbedMovies',
    'VidSrc',
  ]);
  expect(sources.map((source) => source.url), urls);
}

void main() {
  group('StreamResolverService', () {
    test('gera as quatro fontes para um filme TMDB', () {
      final sources = StreamResolverService.resolveFromContentId(
        'tmdb_693134_movie',
      );

      expectSources(sources, [
        'https://superflixapi.quest/filme/693134',
        'https://embed.warezcdn.net/filme/693134',
        'https://myembed.biz/filme/693134',
        'https://vidsrc.cc/v2/embed/movie/693134',
      ]);
      expect(sources[0].isEmbed, isTrue);
      expect(sources[0].priority, 1);
      expect(sources[0].server, 'SuperFlix');
      expect(sources[0].quality, '1080p Full HD');
    });

    test(
      'inclui temporada e episódio no endereço de série para os servidores',
      () {
        final sources = StreamResolverService.resolveFromContentId(
          'tmdb_1396_series',
          season: 2,
          episode: 3,
        );

        expectSources(sources, [
          'https://superflixapi.quest/serie/1396/2/3',
          'https://embed.warezcdn.net/serie/1396/2/3',
          'https://myembed.biz/serie/1396/2/3',
          'https://vidsrc.cc/v2/embed/tv/1396/2/3',
        ]);
      },
    );

    test('abre a lista do fornecedor quando não há episódio escolhido', () {
      for (final type in ['series', 'tv', 'anime', 'dorama']) {
        final sources = StreamResolverService.resolveFromContentId(
          'tmdb_1396_$type',
        );

        expectSources(sources, [
          'https://superflixapi.quest/serie/1396',
          'https://embed.warezcdn.net/serie/1396',
          'https://myembed.biz/serie/1396',
          'https://vidsrc.cc/v2/embed/tv/1396',
        ]);
      }
    });

    test('não inventa episódio quando somente a temporada é informada', () {
      final sources = StreamResolverService.resolveFromContentId(
        'tmdb_1396_series',
        season: 2,
      );

      expectSources(sources, [
        'https://superflixapi.quest/serie/1396',
        'https://embed.warezcdn.net/serie/1396',
        'https://myembed.biz/serie/1396',
        'https://vidsrc.cc/v2/embed/tv/1396',
      ]);
    });

    test('mapeia filme interno para o TMDB dos servidores', () {
      final sources = StreamResolverService.resolveFromContentId('mf_1');

      expectSources(sources, [
        'https://superflixapi.quest/filme/693134',
        'https://embed.warezcdn.net/filme/693134',
        'https://myembed.biz/filme/693134',
        'https://vidsrc.cc/v2/embed/movie/693134',
      ]);
    });

    test('preserva o episódio escolhido para uma série interna', () {
      final sources = StreamResolverService.resolveFromContentId(
        'sc_5',
        season: 2,
        episode: 3,
      );

      expectSources(sources, [
        'https://superflixapi.quest/serie/1396/2/3',
        'https://embed.warezcdn.net/serie/1396/2/3',
        'https://myembed.biz/serie/1396/2/3',
        'https://vidsrc.cc/v2/embed/tv/1396/2/3',
      ]);
    });

    test('abre a lista de uma série interna sem episódio escolhido', () {
      final sources = StreamResolverService.resolveFromContentId('sc_5');

      expectSources(sources, [
        'https://superflixapi.quest/serie/1396',
        'https://embed.warezcdn.net/serie/1396',
        'https://myembed.biz/serie/1396',
        'https://vidsrc.cc/v2/embed/tv/1396',
      ]);
    });

    test('não gera fonte para ID interno desconhecido', () {
      expect(
        StreamResolverService.resolveFromContentId('mf_desconhecido'),
        isEmpty,
      );
    });
  });
}
