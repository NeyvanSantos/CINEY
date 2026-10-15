import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/platform/app_platform_services.dart';
import '../../../plugin_engine/models/stream_source.dart';

/// Abre o motor nativo incorporado ao CiNey, no mesmo pacote Android.
class CastLiteBridgeService {
  static int _sequence = 0;

  static Map<String, Object?> buildRequest({
    required StreamSource source,
    required String title,
    required String posterUrl,
    List<StreamSource>? sources,
    int resumePositionMs = 0,
    String? contentId,
    int? season,
    int? episode,
  }) {
    final available = sources?.isNotEmpty == true ? sources! : [source];
    var index = available.indexWhere(
      (candidate) =>
          candidate.url == source.url && candidate.server == source.server,
    );
    final effective = index < 0 ? [source, ...available] : available;
    if (index < 0) index = 0;
    return {
      'version': 1,
      'requestId': '${DateTime.now().microsecondsSinceEpoch}_${_sequence++}',
      'title': title,
      'posterUrl': posterUrl,
      'contentId': contentId,
      'season': season,
      'episode': episode,
      'positionMs': resumePositionMs < 0 ? 0 : resumePositionMs,
      'sourceIndex': index,
      'sources': [
        for (final candidate in effective)
          {
            'url': candidate.url,
            'server': candidate.server,
            'isEmbed': candidate.isEmbed,
            'isDirect': candidate.isDirect && !candidate.isEmbed,
            'mimeType': candidate.isM3U8 && !candidate.isEmbed
                ? 'application/vnd.apple.mpegurl'
                : null,
            'headers': candidate.headers ?? const <String, String>{},
            'audioLanguage': candidate.audioType == AudioType.dubbed
                ? 'pt'
                : null,
          },
      ],
    };
  }

  static Future<bool> launchCast({
    required BuildContext context,
    required StreamSource source,
    required String title,
    required String posterUrl,
    List<StreamSource>? sources,
    int resumePositionMs = 0,
    String? contentId,
    int? season,
    int? episode,
  }) async {
    try {
      final sender = AppPlatformServices.current.casting;
      if (sender == null || !await sender.isAvailable()) {
        if (context.mounted) {
          _showMessage(
            context,
            'A transmissão está disponível no CiNey para celular Android.',
          );
        }
        return false;
      }
      if (!context.mounted) return false;
      await sender.open(
        buildRequest(
          source: source,
          title: title,
          posterUrl: posterUrl,
          sources: sources,
          resumePositionMs: resumePositionMs,
          contentId: contentId,
          season: season,
          episode: episode,
        ),
      );
      return true;
    } on MissingPluginException {
      if (context.mounted) {
        _showMessage(
          context,
          'Instale a versão do CiNey com transmissão integrada.',
        );
      }
      return false;
    } catch (error) {
      AppLogger.warn(
        'Falha ao abrir transmissão interna (${error.runtimeType}).',
        tag: 'CAST',
      );
      if (context.mounted) {
        _showMessage(
          context,
          'Não foi possível abrir a transmissão. Tente novamente.',
        );
      }
      return false;
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }
}
