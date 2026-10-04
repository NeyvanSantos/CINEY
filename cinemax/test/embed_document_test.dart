import 'package:cinemax/features/player/services/embed_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';

void main() {
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
