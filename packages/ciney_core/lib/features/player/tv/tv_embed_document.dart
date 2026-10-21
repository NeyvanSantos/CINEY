import 'dart:convert';
import 'tv_source_policy.dart';

const tvEmbedBaseUrl = 'https://ciney.invalid/tv-player/';

String tvEmbedBaseUrlFor(String url) => Uri.parse(url).scheme == 'http'
    ? 'http://ciney.invalid/tv-player/'
    : tvEmbedBaseUrl;

String buildTvEmbedDocument(String url) {
  if (!TvSourcePolicy.isHttpUrl(url)) {
    throw const FormatException('Invalid embed URL');
  }
  final escaped = const HtmlEscape().convert(url);
  // The Android host installs its media observer before loading this document.
  return '''<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body,iframe{margin:0;width:100%;height:100%;border:0;background:#000;overflow:hidden}</style>
</head><body><iframe id="provider" src="$escaped" title="Player do fornecedor"
allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe>
</body></html>''';
}
