import 'package:cinemax/features/player/services/embed_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';

void main() {
  test('EmbedMovies inicia na primeira abertura sem ponto salvo', () {
    final config = buildEmbedPlaybackConfiguration(
      playerUrl: 'https://myembed.biz/filme/969681',
      resumePlayback: true,
      resumePositionMs: 0,
      durationMs: 0,
    );
    expect(config, contains('__cineyAutoStart = true'));
    expect(config, contains('__cineyResumePositionSeconds = 0.0'));
    expect(config, contains('__cineyProviderPath = "/filme/969681"'));
  });

  test('desligar retomada não impede início automático no EmbedMovies', () {
    final config = buildEmbedPlaybackConfiguration(
      playerUrl: 'https://myembed.biz/serie/1396/2/3',
      resumePlayback: false,
      resumePositionMs: 300123,
      durationMs: 1200000,
    );
    expect(config, contains('__cineyAutoStart = true'));
    expect(config, contains('__cineyResumePositionSeconds = 0;'));
    expect(config, contains('__cineyExpectedDurationSeconds = 1200.0'));
  });

  test('outros fornecedores preservam início condicionado à retomada', () {
    for (final resumePlayback in [true, false]) {
      final config = buildEmbedPlaybackConfiguration(
        playerUrl: 'https://superflixapi.quest/filme/969681',
        resumePlayback: resumePlayback,
        resumePositionMs: 300123,
        durationMs: 1200000,
      );
      expect(config, contains('__cineyAutoStart = $resumePlayback'));
      if (resumePlayback) {
        expect(config, contains('__cineyResumePositionSeconds = 300.123'));
      }
    }
    for (final url in [
      'https://superflixapi.quest/filme/969681',
      'https://myembed.biz.example/filme/969681',
    ]) {
      expect(
        buildEmbedPlaybackConfiguration(
          playerUrl: url,
          resumePlayback: true,
          resumePositionMs: 0,
          durationMs: 0,
        ),
        contains('__cineyAutoStart = false'),
      );
    }
  });

  test('incorpora player em iframe com permissões e sem controles do app', () {
    final doc = parse(
      buildEmbedDocument(
        'https://myembed.biz/filme/969681',
        'window.bridgeReady = true;',
      ),
    );
    final frame = doc.querySelector('iframe')!;
    expect(frame.attributes['src'], 'https://myembed.biz/filme/969681');
    expect(frame.attributes['allow'], contains('autoplay'));
    expect(frame.attributes['allow'], contains('encrypted-media'));
    expect(frame.attributes.containsKey('allowfullscreen'), isTrue);
    expect(frame.attributes['tabindex'], '0');
    expect(doc.querySelectorAll('video, button'), isEmpty);
    expect(doc.querySelector('script')!.text, contains('window.bridgeReady'));
  });

  test('URL não pode inserir atributos ou scripts no documento local', () {
    const url = 'https://myembed.biz/filme/1?q=" onload="alert(1)&a=2';
    final doc = parse(buildEmbedDocument(url, 'const text = "</script>";'));
    final frame = doc.querySelector('iframe')!;
    expect(frame.attributes['src'], url);
    expect(frame.attributes.containsKey('onload'), isFalse);
    expect(doc.querySelectorAll('script'), hasLength(1));
    expect(doc.querySelector('script')!.text, contains(r'<\/script>'));
  });
}
