import 'dart:convert';

/// Local document hosting the provider's player as an iframe, as required by
/// EmbedMovies. This origin belongs to the app; no page is fetched from it.
const embedDocumentBaseUrl = 'https://cinemax.invalid/player/';

String buildEmbedDocument(String playerUrl, String bridgeScript) {
  final src = const HtmlEscape(HtmlEscapeMode.attribute).convert(playerUrl);
  final script = bridgeScript.replaceAll(
    RegExp('</script', caseSensitive: false),
    r'<\/script',
  );
  return '''<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Player EmbedMovies</title>
  <style>
    html, body { margin: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
    iframe { display: block; width: 100%; height: 100%; border: 0; }
  </style>
</head>
<body>
  <iframe src="$src" title="Player do fornecedor" tabindex="0" frameborder="0" scrolling="no"
    allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
    allowfullscreen></iframe>
  <script>$script</script>
</body>
</html>''';
}
