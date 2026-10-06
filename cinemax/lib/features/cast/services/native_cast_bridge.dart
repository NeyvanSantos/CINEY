import 'package:flutter/services.dart';

class NativeCastBridge {
  static const _channel = MethodChannel('com.cinemax.cinemax/cast');

  static bool isDirectMediaUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return false;
    }
    final path = uri.path.toLowerCase();
    if (path.contains('/stream') || path.contains('/hls/')) return true;
    final target = (uri.queryParameters['url'] ?? path).toLowerCase();
    return const [
      '.mp4',
      '.m3u8',
      '.mpd',
      '.webm',
      '.mkv',
      '.mov',
      '.ts',
      '.avi',
      '.flv',
      '.3gp',
    ].any((ext) => target.contains(ext) || path.endsWith(ext));
  }

  static String contentTypeFor(String url) {
    final uri = Uri.tryParse(url);
    final target = (uri?.queryParameters['url'] ?? url).toLowerCase();
    if (target.contains('.m3u8') ||
        target.contains('/hls/') ||
        target.contains('application/x-mpegurl')) {
      return 'application/x-mpegURL';
    }
    if (target.contains('.mpd') || target.contains('manifest.mpd')) {
      return 'application/dash+xml';
    }
    if (target.endsWith('.webm')) return 'video/webm';
    if (target.endsWith('.mkv')) return 'video/x-matroska';
    return 'video/mp4';
  }

  static Future<bool> castMedia({
    required String url,
    required String title,
    String? posterUrl,
  }) async {
    final uri = Uri.tryParse(url);
    final isHttpSource =
        uri != null &&
        {'http', 'https'}.contains(uri.scheme) &&
        uri.host.isNotEmpty;

    if (!isHttpSource) return false;

    try {
      final result = await _channel.invokeMethod<bool>('castMedia', {
        'url': url,
        'title': title,
        'posterUrl': posterUrl,
        'contentType': isDirectMediaUrl(url)
            ? contentTypeFor(url)
            : 'text/html',
      });
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  static Future<bool> isCastConnected() async {
    try {
      return await _channel.invokeMethod<bool>('isCastConnected') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> castDeviceName() async {
    try {
      return await _channel.invokeMethod<String>('castDeviceName');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> stopCasting() async {
    try {
      return await _channel.invokeMethod<bool>('stopCasting') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre o Google Home para o usuário iniciar o espelhamento de tela.
  /// O retorno confirma somente a abertura do app, sem indicar conexão com a TV.
  /// Lança [PlatformException] com HOME_NOT_INSTALLED se o app não estiver disponível.
  static Future<bool> openGoogleHome() async {
    return await _channel.invokeMethod<bool>('openGoogleHome') ?? false;
  }

  /// Abre a página oficial do Google Home após a escolha do usuário de instalá-lo.
  static Future<bool> openGoogleHomeStore() async {
    return await _channel.invokeMethod<bool>('openGoogleHomeStore') ?? false;
  }

  /// Abre diretamente a tela nativa de Transmissão / Espelhamento de tela do Android (Smart View / Cast Settings)
  static Future<bool> openSystemCast() async {
    try {
      final result = await _channel.invokeMethod<bool>('openSystemCast');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Envia o link do vídeo para o seletor nativo do Android (Web Video Caster, BubbleUPnP, Smart View, VLC, etc.)
  static Future<bool> openExternalPlayer({
    required String url,
    String? title,
  }) async {
    if (!isDirectMediaUrl(url)) return false;
    try {
      final result = await _channel.invokeMethod<bool>('openExternalPlayer', {
        'url': url,
        'title': title ?? 'Filme / Série',
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openWebVideoCaster({
    required String url,
    String? title,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('openWebVideoCaster', {
            'url': url,
            'title': title ?? 'Filme / Série',
          }) ??
          false;
    } on PlatformException {
      rethrow;
    }
  }

  static Future<bool> openWebVideoCasterStore() async {
    return await _channel.invokeMethod<bool>('openWebVideoCasterStore') ??
        false;
  }

  /// Atualiza a lista de domínios de embed permitidos no lado nativo (Kotlin).
  /// Isso elimina a necessidade de atualizar o APK quando novos domínios surgem.
  static Future<bool> updateAllowedHosts(List<String> hosts) async {
    try {
      return await _channel.invokeMethod<bool>('updateAllowedHosts', {
            'hosts': hosts,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Retorna a lista atual de domínios de embed permitidos no lado nativo.
  static Future<List<String>> getAllowedHosts() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getAllowedHosts');
      return result?.cast<String>() ?? [];
    } catch (_) {
      return [];
    }
  }
}

