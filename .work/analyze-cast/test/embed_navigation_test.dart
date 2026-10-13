import 'package:cinemax/features/player/services/embed_navigation.dart';
import 'package:cinemax/features/player/services/embed_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mantém documento local no topo e fornecedor dentro do iframe', () {
    expect(
      allowsEmbedNavigation(
        'https://myembed.biz/filme/969681',
        embedDocumentBaseUrl,
      ),
      isTrue,
    );
    expect(
      allowsEmbedNavigation(
        'https://myembed.biz/',
        'https://myembed.biz/filme/969681',
      ),
      isFalse,
    );
    expect(
      allowsEmbedNavigation(
        'https://myembed.biz/',
        'https://myembed.biz/filme/969681',
        mainFrame: false,
      ),
      isTrue,
    );
  });
  test('bloqueia anúncio externo, domínio parecido e aplicativo externo', () {
    const source = 'https://myembed.biz/';
    for (final url in [
      'https://ads.example/',
      'https://streamingnow.mov.attacker.test/',
      'https://fakemultiembed.mov/',
      'intent://player',
      'javascript:alert(1)',
    ]) {
      expect(allowsEmbedNavigation(source, url), isFalse, reason: url);
    }
    expect(
      allowsEmbedNavigation(
        source,
        'https://media.example/video',
        mainFrame: false,
      ),
      isTrue,
    );
    expect(
      allowsEmbedNavigation(source, 'intent://player', mainFrame: false),
      isFalse,
    );
  });
}
