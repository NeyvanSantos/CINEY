import 'package:dio/dio.dart';
import '../../../core/services/app_logger.dart';
import '../../../plugin_engine/models/stream_source.dart';
import '../../../plugin_engine/runtime/stream_resolver.dart';
import 'tv_source_policy.dart';

/// Optional control plane; no video bytes travel through this service.
class TvEngineClient {
  TvEngineClient({
    Dio? dio,
    this.endpoint = const String.fromEnvironment('CINEY_PLAYER_ENGINE_URL'),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 4),
               receiveTimeout: const Duration(seconds: 5),
               sendTimeout: const Duration(seconds: 4),
             ),
           );
  final Dio _dio;
  final String endpoint;

  /// Null means local fallback. An empty list is an authoritative NO_SOURCES.
  Future<List<StreamSource>?> resolve(
    String contentId, {
    int? season,
    int? episode,
  }) async {
    if (endpoint.isEmpty) return null;
    if (!TvSourcePolicy.isHttpUrl(endpoint)) {
      AppLogger.warn(
        'Endereço do serviço inválido; usando fontes locais.',
        tag: 'TV_ENGINE',
      );
      return null;
    }
    final catalogId = StreamResolverService.catalogIdFor(contentId);
    final tmdbId = StreamResolverService.extractTmdbId(catalogId);
    final imdbId = RegExp(r'^tt\d{7,10}$').hasMatch(catalogId)
        ? catalogId
        : null;
    if (tmdbId == null && imdbId == null) return null;
    final series =
        StreamResolverService.isTvContent(catalogId) || season != null;
    try {
      final response = await _dio.post<Object?>(
        '${endpoint.replaceFirst(RegExp(r'/+$'), '')}/v1/resolve',
        data: {
          'type': series ? 'series' : 'movie',
          'tmdbId': ?tmdbId,
          'imdbId': ?imdbId,
          if (series) 'season': season,
          if (series) 'episode': episode,
        },
      );
      return parseSources(response.data);
    } on DioException catch (error) {
      final data = error.response?.data;
      if (error.response?.statusCode == 404 &&
          data is Map &&
          data['error'] is Map &&
          data['error']['code'] == 'NO_SOURCES') {
        return [];
      }
      AppLogger.warn(
        'Serviço indisponível; usando fontes locais (${error.type.name}).',
        tag: 'TV_ENGINE',
      );
      return null;
    } on FormatException {
      AppLogger.warn(
        'Resposta incompatível; usando fontes locais.',
        tag: 'TV_ENGINE',
      );
      return null;
    }
  }

  static List<StreamSource> parseSources(Object? data) {
    if (data is! Map || data['apiVersion'] != 1 || data['sources'] is! List) {
      throw const FormatException('Invalid engine response');
    }
    final entries = data['sources'] as List;
    if (entries.length > 32) throw const FormatException('Too many sources');
    return entries.map((entry) {
      if (entry is! Map ||
          entry['url'] is! String ||
          !TvSourcePolicy.isHttpUrl(entry['url'] as String) ||
          entry['server'] is! String ||
          (entry['server'] as String).isEmpty ||
          entry['priority'] is! int ||
          !const ['embed', 'native'].contains(entry['kind'])) {
        throw const FormatException('Invalid source');
      }
      final native = entry['kind'] == 'native';
      if (native &&
          !const [
            'video/mp4',
            'video/webm',
            'application/dash+xml',
            'application/vnd.apple.mpegurl',
            'application/x-mpegURL',
          ].contains(entry['mimeType'])) {
        throw const FormatException('Native media type required');
      }
      final source = TvEngineSource(
        mimeType: entry['mimeType'] is String
            ? entry['mimeType'] as String
            : 'text/html',
        url: entry['url'] as String,
        server: entry['server'] as String,
        quality: 'Conforme o fornecedor',
        priority: entry['priority'] as int,
        isEmbed: !native,
        isDirect: native,
        isM3U8: const [
          'application/vnd.apple.mpegurl',
          'application/x-mpegURL',
        ].contains(entry['mimeType']),
      );
      if (native && TvSourcePolicy.classify(source) != TvSourceKind.native) {
        throw const FormatException('Embed cannot be native');
      }
      return source;
    }).toList();
  }

  void close() => _dio.close();
}
