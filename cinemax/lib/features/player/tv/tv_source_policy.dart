import '../../../plugin_engine/models/stream_source.dart';
import 'package:video_player/video_player.dart';

enum TvSourceKind { embed, native, unsupported }

class TvEngineSource extends StreamSource {
  const TvEngineSource({
    required super.url,
    required super.server,
    required super.quality,
    required super.priority,
    required super.isEmbed,
    required super.isDirect,
    required this.mimeType,
    super.isM3U8,
  });
  final String mimeType;
}

/// Classification is explicit. A query containing .mp4 is not a media URL.
class TvSourcePolicy {
  static VideoFormat? nativeFormat(StreamSource source) {
    if (source is TvEngineSource) {
      if (source.mimeType == 'application/dash+xml') return VideoFormat.dash;
      if (const [
        'application/vnd.apple.mpegurl',
        'application/x-mpegURL',
      ].contains(source.mimeType)) {
        return VideoFormat.hls;
      }
    }
    return source.isM3U8 ? VideoFormat.hls : null;
  }

  static bool isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        const ['http', 'https'].contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  static TvSourceKind classify(StreamSource source) {
    if (!isHttpUrl(source.url)) return TvSourceKind.unsupported;
    final host = Uri.parse(source.url).host;
    if (source.isEmbed ||
        const [
          'myembed.biz',
          'superflixapi.quest',
          'playerflix.ink',
        ].any((domain) => host == domain || host.endsWith('.$domain'))) {
      return TvSourceKind.embed;
    }
    return source.isDirect ? TvSourceKind.native : TvSourceKind.unsupported;
  }
}
