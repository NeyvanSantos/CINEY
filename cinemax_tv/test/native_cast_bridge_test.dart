import 'package:cinemax/features/cast/services/native_cast_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.cinemax.cinemax/cast');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('abre o Google Home sem iniciar uma sessão de transmissão', () async {
    expect(await NativeCastBridge.openGoogleHome(), isTrue);
    expect(calls.map((call) => call.method), ['openGoogleHome']);
    expect(calls.single.arguments, isNull);
  });

  test(
    'propaga a ausência do Google Home sem abrir a loja automaticamente',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        throw PlatformException(code: 'HOME_NOT_INSTALLED');
      });

      await expectLater(
        NativeCastBridge.openGoogleHome(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'HOME_NOT_INSTALLED',
          ),
        ),
      );
      expect(calls.map((call) => call.method), ['openGoogleHome']);
    },
  );

  test('propaga falha de abertura do Google Home', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'HOME_LAUNCH_ERROR');
    });

    await expectLater(
      NativeCastBridge.openGoogleHome(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'HOME_LAUNCH_ERROR',
        ),
      ),
    );
  });

  test('não assume que o Google Home abriu quando o retorno é nulo', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await NativeCastBridge.openGoogleHome(), isFalse);
  });

  test('abre a loja somente pela ação de instalação explícita', () async {
    expect(await NativeCastBridge.openGoogleHomeStore(), isTrue);
    expect(calls.map((call) => call.method), ['openGoogleHomeStore']);
    expect(calls.single.arguments, isNull);
  });

  test(
    'permite URLs de embed/iframe ao usar o Chromecast para espelhar o app',
    () async {
      const url = 'https://myembed.biz/filme/550';
      expect(NativeCastBridge.isDirectMediaUrl(url), isFalse);
      expect(
        await NativeCastBridge.castMedia(url: url, title: 'Filme'),
        isTrue,
      );
      expect(calls.single.method, 'castMedia');
      expect(calls.single.arguments['url'], url);
      expect(calls.single.arguments['title'], 'Filme');
    },
  );

  test('envia páginas EmbedMovies ao Web Video Caster', () async {
    const url = 'https://myembed.biz/filme/550';
    expect(
      await NativeCastBridge.openWebVideoCaster(url: url, title: 'Filme'),
      isTrue,
    );
    expect(calls.single.method, 'openWebVideoCaster');
    expect(calls.single.arguments, {'url': url, 'title': 'Filme'});
  });

  test(
    'recusa páginas embed quando o app tenta abrir um player externo',
    () async {
      const invalidUrls = [
        'https://embedmovies.org/filme/550',
        'https://embedmovies.org/filme/550?source=film.mp4',
        'https://example.com/embed?url=https://cdn.example.com/film.m3u8',
        'https://example.com/watch#film.mpd',
        'https://example.com/movie.mp4/watch',
        'https://example.com/movie.mp4.html',
        'https:///movie.mp4',
        'file:///movie.mp4',
        'javascript:movie.mp4',
      ];

      for (final url in invalidUrls) {
        expect(NativeCastBridge.isDirectMediaUrl(url), isFalse, reason: url);
        expect(await NativeCastBridge.openExternalPlayer(url: url), isFalse);
      }
      expect(calls, isEmpty);
    },
  );

  test(
    'aceita arquivos e playlists diretos com parâmetros assinados',
    () async {
      const url = 'https://cdn.example.com/film.M3U8?token=abc&name=film.mp4';
      expect(NativeCastBridge.isDirectMediaUrl(url), isTrue);
      expect(NativeCastBridge.contentTypeFor(url), 'application/x-mpegURL');
      expect(
        await NativeCastBridge.castMedia(url: url, title: 'Filme'),
        isTrue,
      );
      expect(calls.single.method, 'castMedia');
      expect(calls.single.arguments['contentType'], 'application/x-mpegURL');
      expect(calls.single.arguments['url'], url);
    },
  );

  test('usa o formato do caminho em vez do formato sugerido pela query', () {
    expect(
      NativeCastBridge.contentTypeFor(
        'https://example.com/film.mp4?name=a.m3u8',
      ),
      'video/mp4',
    );
    expect(
      NativeCastBridge.contentTypeFor('https://example.com/film.mpd?token=123'),
      'application/dash+xml',
    );
  });

  test('envia arquivo direto ao player externo', () async {
    const url = 'https://cdn.example.com/film.mp4?token=abc';
    expect(
      await NativeCastBridge.openExternalPlayer(url: url, title: 'Filme'),
      isTrue,
    );
    expect(calls.single.method, 'openExternalPlayer');
    expect(calls.single.arguments, {'url': url, 'title': 'Filme'});
  });
}
