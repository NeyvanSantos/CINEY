import 'dart:convert';

/// Local document hosting the provider's player as an iframe, as required by
/// EmbedMovies. This origin belongs to the app; no page is fetched from it.
const embedDocumentBaseUrl = 'https://cinemax.invalid/player/';

/// TV sources and EmbedMovies start on first play; resuming is independent.
String buildEmbedPlaybackConfiguration({
  required String playerUrl,
  required bool resumePlayback,
  required int resumePositionMs,
  required int durationMs,
  bool isTv = false,
}) {
  final provider = Uri.parse(playerUrl);
  final autoStart =
      isTv ||
      (provider.scheme == 'https' && provider.host == 'myembed.biz') ||
      (resumePlayback && resumePositionMs > 0);
  return 'window.__cineyResumePositionSeconds = ${resumePlayback ? resumePositionMs / 1000 : 0};\n'
      'window.__cineyExpectedDurationSeconds = ${durationMs / 1000};\n'
      'window.__cineyAutoStart = $autoStart;\n'
      'window.__cineyIsTv = $isTv;\n'
      'window.__cineyProviderHost = ${jsonEncode(provider.host)};\n'
      'window.__cineyProviderPath = ${jsonEncode(provider.path)};\n';
}

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
