import 'dart:convert';
import 'package:cinemax/features/player/tv/tv_embed_document.dart';
import 'package:cinemax/features/player/tv/tv_engine_client.dart';
import 'package:cinemax/features/player/tv/tv_source_policy.dart';
import 'package:cinemax/plugin_engine/models/stream_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

Map<String, Object> response({
  String kind = 'embed',
  String url = 'https://myembed.biz/filme/1',
}) => {
  'apiVersion': 1,
  'sources': [
    {
      'url': url,
      'server': 'Teste',
      'kind': kind,
      'priority': 1,
      'mimeType': kind == 'native' ? 'video/mp4' : 'text/html',
    },
  ],
};

void main() {
  test(
    'extensionless adaptive sources retain explicit HLS and DASH formats',
    () {
      for (final pair in [
        ('application/dash+xml', VideoFormat.dash),
        ('application/vnd.apple.mpegurl', VideoFormat.hls),
      ]) {
        final data = response(kind: 'native', url: 'https://media.test/stream');
        ((data['sources'] as List).single as Map)['mimeType'] = pair.$1;
        expect(
          TvSourcePolicy.nativeFormat(TvEngineClient.parseSources(data).single),
          pair.$2,
        );
      }
    },
  );
  test(
    'document preserves iframe permissions and escapes untrusted URL attributes',
    () {
      final document = buildTvEmbedDocument(
        'https://provider.test/a?x=" onload="alert(1)&a=b',
      );
      expect(
        document,
        contains(
          'src="https:&#47;&#47;provider.test&#47;a?x=&quot; onload=&quot;alert(1)&amp;a=b"',
        ),
      );
      expect(document, contains('allowfullscreen'));
      expect(document, isNot(contains('<script')));
      expect(
        () => buildTvEmbedDocument('javascript:alert(1)'),
        throwsFormatException,
      );
    },
  );

  test('known embeds never become native based on extension or query', () {
    for (final url in [
      'https://myembed.biz/filme/1?video=a.mp4',
      'https://cdn.myembed.biz/1.mp4',
      'https://superflixapi.quest/filme/1',
    ]) {
      expect(
        TvSourcePolicy.classify(
          StreamSource(url: url, quality: '', server: 'test'),
        ),
        TvSourceKind.embed,
      );
    }
    expect(
      TvSourcePolicy.classify(
        const StreamSource(url: 'file:///private', quality: '', server: 'test'),
      ),
      TvSourceKind.unsupported,
    );
    expect(
      TvSourcePolicy.classify(
        const StreamSource(
          url: 'https://video.test/file.mp4',
          quality: '',
          server: 'test',
        ),
      ),
      TvSourceKind.native,
    );
    expect(
      TvSourcePolicy.classify(
        const StreamSource(
          url: 'https://video.test/page?file=x.mp4',
          quality: '',
          server: 'test',
          isDirect: false,
        ),
      ),
      TvSourceKind.unsupported,
    );
  });

  test(
    'engine protocol rejects unsafe sources and native embed declarations',
    () {
      expect(TvEngineClient.parseSources(response()).single.isEmbed, isTrue);
      expect(
        () => TvEngineClient.parseSources(response(kind: 'native')),
        throwsFormatException,
      );
      expect(
        () => TvEngineClient.parseSources(
          response(url: 'https://user:secret@provider.test'),
        ),
        throwsFormatException,
      );
      expect(
        () => TvEngineClient.parseSources({'apiVersion': 2, 'sources': []}),
        throwsFormatException,
      );
      expect(
        TvEngineClient.parseSources(
          response(kind: 'native', url: 'https://video.test/stream'),
        ).single.isDirect,
        isTrue,
      );
    },
  );

  test(
    'TV client maps catalog IDs and episode identity into request',
    () async {
      final dio = Dio();
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: response(),
              ),
            );
          },
        ),
      );
      final engine = TvEngineClient(
        dio: dio,
        endpoint: 'http://localhost:8787/',
      );
      addTearDown(engine.close);
      await engine.resolve('mf_1');
      await engine.resolve('tmdb_1396_series', season: 2, episode: 3);
      expect(requests[0].data, {'type': 'movie', 'tmdbId': '693134'});
      expect(requests[1].data, {
        'type': 'series',
        'tmdbId': '1396',
        'season': 2,
        'episode': 3,
      });
      expect(requests[0].uri.path, '/v1/resolve');
    },
  );

  test(
    'disabled providers remain disabled; connection and schema failures use local fallback',
    () async {
      final dio = Dio();
      var mode = 'disabled';
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (mode == 'schema') {
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: jsonDecode('{"apiVersion":99}'),
                ),
              );
            } else {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: mode == 'disabled'
                      ? DioExceptionType.badResponse
                      : DioExceptionType.connectionError,
                  response: mode == 'disabled'
                      ? Response(
                          requestOptions: request,
                          statusCode: 404,
                          data: {
                            'error': {'code': 'NO_SOURCES'},
                          },
                        )
                      : null,
                ),
              );
            }
          },
        ),
      );
      final engine = TvEngineClient(
        dio: dio,
        endpoint: 'http://localhost:8787',
      );
      addTearDown(engine.close);
      expect(await engine.resolve('tmdb_1_movie'), isEmpty);
      mode = 'offline';
      expect(await engine.resolve('tmdb_1_movie'), isNull);
      mode = 'schema';
      expect(await engine.resolve('tmdb_1_movie'), isNull);
    },
  );
}
