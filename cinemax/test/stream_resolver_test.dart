import 'package:cinemax/plugin_engine/runtime/stream_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamResolverService', () {
    test('gera EmbedMovies e SuperFlix para um filme TMDB', () {
      final sources = StreamResolverService.resolveFromContentId(
        'tmdb_693134_movie',
      );

      expect(sources, hasLength(2));

      // EmbedMovies (Fonte 1)
      expect(sources[0].url, 'https://myembed.biz/filme/693134');
      expect(sources[0].server, 'EmbedMovies');
      expect(sources[0].isEmbed, isTrue);
      expect(sources[0].priority, 1);

      // SuperFlix (Fonte 2)
      expect(sources[1].url, 'https://superflixapi.monster/filme/693134');
      expect(sources[1].server, 'SuperFlix');
      expect(sources[1].quality, '1080p Full HD');
      expect(sources[1].isEmbed, isTrue);
      expect(sources[1].priority, 2);
    });

    test('inclui temporada e episódio no endereço de série para os servidores', () {
      final sources = StreamResolverService.resolveFromContentId(
        'tmdb_1396_series',
        season: 2,
        episode: 3,
      );

      expect(sources, hasLength(2));
      expect(sources[0].url, 'https://myembed.biz/serie/1396/2/3');
      expect(sources[1].url, 'https://superflixapi.monster/serie/1396/2/3');
    });

    test('abre a lista do fornecedor quando não há episódio escolhido', () {
      for (final type in ['series', 'tv', 'anime', 'dorama']) {
        final sources = StreamResolverService.resolveFromContentId(
          'tmdb_1396_$type',
        );

        expect(sources, hasLength(2), reason: type);
        expect(sources[0].url, 'https://myembed.biz/serie/1396');
        expect(sources[1].url, 'https://superflixapi.monster/serie/1396');
      }
    });

    test('não inventa episódio quando somente a temporada é informada', () {
      final sources = StreamResolverService.resolveFromContentId(
        'tmdb_1396_series',
        season: 2,
      );

      expect(sources, hasLength(2));
      expect(sources[0].url, 'https://myembed.biz/serie/1396');
      expect(sources[1].url, 'https://superflixapi.monster/serie/1396');
    });

    test('mapeia filme interno para o TMDB dos servidores', () {
      final sources = StreamResolverService.resolveFromContentId('mf_1');

      expect(sources, hasLength(2));
      expect(sources[0].url, 'https://myembed.biz/filme/693134');
      expect(sources[1].url, 'https://superflixapi.monster/filme/693134');
    });

    test('preserva o episódio escolhido para uma série interna', () {
      final sources = StreamResolverService.resolveFromContentId(
        'sc_5',
        season: 2,
        episode: 3,
      );

      expect(sources, hasLength(2));
      expect(sources[0].url, 'https://myembed.biz/serie/1396/2/3');
      expect(sources[1].url, 'https://superflixapi.monster/serie/1396/2/3');
    });

    test('abre a lista de uma série interna sem episódio escolhido', () {
      final sources = StreamResolverService.resolveFromContentId('sc_5');

      expect(sources, hasLength(2));
      expect(sources[0].url, 'https://myembed.biz/serie/1396');
      expect(sources[1].url, 'https://superflixapi.monster/serie/1396');
    });

    test('não gera fonte para ID interno desconhecido', () {
      expect(
        StreamResolverService.resolveFromContentId('mf_desconhecido'),
        isEmpty,
      );
    });
  });
}
