import 'dart:convert';

import '../../../plugin_engine/models/stream_source.dart';
import 'tv_source_policy.dart';

/// A playlist observed in the provider's own network session, never a blob URL.
class TvHlsCandidate {
  const TvHlsCandidate(this.url, this.referer, this.headers);

  final String url;
  final String referer;
  final Map<String, String> headers;

  static TvHlsCandidate? parse(String message) {
    if (message.length > 32768) return null;
    try {
      final data = jsonDecode(message);
      if (data is! Map || data['event'] != 'hls') return null;
      final url = data['url'];
      final referer = data['referer'];
      if (url is! String ||
          referer is! String ||
          !TvSourcePolicy.isHttpUrl(url) ||
          !TvSourcePolicy.isHttpUrl(referer)) {
        return null;
      }
      final headers = <String, String>{};
      final supplied = data['headers'];
      if (supplied is Map) {
        for (final entry in supplied.entries) {
          final key = entry.key.toString().toLowerCase();
          final value = entry.value;
          // Transport/cookie headers belong to the Android session.
          if ((key == 'authorization' || key.startsWith('x-')) &&
              RegExp(r'^[a-z0-9-]+$').hasMatch(key) &&
              value is String &&
              value.length <= 4096 &&
              !value.contains(RegExp(r'[\r\n]'))) {
            headers[key] = value;
          }
        }
      }
      return TvHlsCandidate(url, referer, headers);
    } on FormatException {
      return null;
    }
  }

  StreamSource toSource(
    StreamSource provider,
    Map<String, String> sessionHeaders,
  ) => StreamSource(
    url: url,
    server: provider.server,
    quality: provider.quality,
    priority: provider.priority,
    audioType: provider.audioType,
    subtitles: provider.subtitles,
    isM3U8: true,
    headers: {
      ...headers,
      'Referer': referer,
      'Origin': Uri.parse(referer).origin,
      ...sessionHeaders,
    },
  );
}
