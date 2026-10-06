import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/services/app_logger.dart';

/// Resultado da extração de fluxo multimídia via sniffer
class SniffedStreamResult {
  final String url;
  final Map<String, String> headers;
  final String? subtitleUrl;
  final bool isM3U8;
  final String? mimeType;

  const SniffedStreamResult({
    required this.url,
    this.headers = const {},
    this.subtitleUrl,
    this.isM3U8 = false,
    this.mimeType,
  });

  @override
  String toString() => 'SniffedStreamResult(url: $url, isM3U8: $isM3U8, headers: $headers)';
}

/// Sniffer inteligente de mídia em segundo plano
/// Baseado na arquitetura e nas regras de inspeção do crx-webcast-reloaded
class MediaStreamSniffer {
  static final RegExp _mediaRegex = RegExp(
    r'\.(m3u8|mp4|mpd|webm|mkv|mov|avi|flv|ts|3gp|m4v|ism)(\?.*)?$',
    caseSensitive: false,
  );

  static final RegExp _captionRegex = RegExp(
    r'\.(vtt|srt)(\?.*)?$',
    caseSensitive: false,
  );

  /// Script de injeção JavaScript para interceptação profunda de chamadas de rede e tags de mídia
  static const String _snifferJsHook = '''
(function() {
  if (window.__cinemaxSnifferActive) return;
  window.__cinemaxSnifferActive = true;

  function reportMedia(url, type) {
    if (!url || typeof url !== 'string') return;
    url = url.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) return;

    // Filtra anúncios e beacons conhecidos
    if (url.includes('google-analytics') || url.includes('doubleclick') || url.includes('adnxs') || url.includes('facebook')) return;

    if (window.MediaSnifferChannel) {
      window.MediaSnifferChannel.postMessage(JSON.stringify({
        url: url,
        type: type || 'video',
        referer: window.location.href,
        origin: window.location.origin
      }));
    }
  }

  function isMediaUrl(url) {
    if (!url || typeof url !== 'string') return false;
    const clean = url.split('?')[0].toLowerCase();
    return clean.endsWith('.m3u8') || 
           clean.endsWith('.mp4') || 
           clean.endsWith('.mpd') || 
           clean.endsWith('.webm') || 
           clean.endsWith('.mkv') || 
           clean.endsWith('.ts') ||
           clean.includes('/hls/') ||
           clean.includes('playlist.m3u8') ||
           clean.includes('manifest.mpd');
  }

  function isCaptionUrl(url) {
    if (!url || typeof url !== 'string') return false;
    const clean = url.split('?')[0].toLowerCase();
    return clean.endsWith('.vtt') || clean.endsWith('.srt');
  }

  // 1. Hook XMLHttpRequest
  try {
    const origOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url) {
      if (typeof url === 'string') {
        if (isMediaUrl(url)) reportMedia(url, 'xhr');
        if (isCaptionUrl(url)) reportMedia(url, 'caption');
      }
      return origOpen.apply(this, arguments);
    };
  } catch(e) {}

  // 2. Hook Fetch API
  try {
    const origFetch = window.fetch;
    window.fetch = function(input, init) {
      const url = (typeof input === 'string') ? input : (input && input.url ? input.url : null);
      if (url) {
        if (isMediaUrl(url)) reportMedia(url, 'fetch');
        if (isCaptionUrl(url)) reportMedia(url, 'caption');
      }
      return origFetch.apply(this, arguments);
    };
  } catch(e) {}

  // 3. Monitor de tags <video>, <source> e <track>
  function scanMediaElements() {
    try {
      const videos = document.querySelectorAll('video');
      videos.forEach(v => {
        if (v.src && isMediaUrl(v.src)) reportMedia(v.src, 'video_tag');
        if (v.currentSrc && isMediaUrl(v.currentSrc)) reportMedia(v.currentSrc, 'video_currentSrc');
      });
      const sources = document.querySelectorAll('source');
      sources.forEach(s => {
        if (s.src && isMediaUrl(s.src)) reportMedia(s.src, 'source_tag');
      });
      const tracks = document.querySelectorAll('track');
      tracks.forEach(t => {
        if (t.src && isCaptionUrl(t.src)) reportMedia(t.src, 'track_tag');
      });
    } catch(e) {}
  }

  // 4. Observer de mutação para pegar elementos adicionados dinamicamente
  try {
    const observer = new MutationObserver(function() {
      scanMediaElements();
    });
    observer.observe(document.documentElement || document.body, { childList: true, subtree: true });
  } catch(e) {}

  // 5. Polling de verificação periódica
  setInterval(scanMediaElements, 800);
  scanMediaElements();
})();
''';

  /// Verifica se a URL já é diretamente reproduzível (sem necessidade de sniffer)
  static bool isDirectMediaUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      return false;
    }
    final path = uri.path.toLowerCase();
    return _mediaRegex.hasMatch(path) || path.contains('.m3u8') || path.contains('.mpd');
  }

  /// Retorna o Content-Type apropriado
  static String getContentType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return 'application/x-mpegURL';
    if (lower.contains('.mpd')) return 'application/dash+xml';
    if (lower.contains('.webm')) return 'video/webm';
    if (lower.contains('.mkv')) return 'video/x-matroska';
    return 'video/mp4';
  }

  /// Cria e configura um WebViewController pronto para o processo de sniffing
  static WebViewController createSnifferController({
    required Function(SniffedStreamResult) onMediaFound,
  }) {
    late final WebViewController controller;

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..addJavaScriptChannel(
        'MediaSnifferChannel',
        onMessageReceived: (message) {
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            final mediaUrl = data['url']?.toString();
            if (mediaUrl != null && mediaUrl.isNotEmpty) {
              final type = data['type']?.toString();
              if (type == 'caption') {
                // Legenda encontrada
                return;
              }
              final referer = data['referer']?.toString() ?? '';
              final origin = data['origin']?.toString() ?? '';
              final headers = <String, String>{
                if (referer.isNotEmpty) 'Referer': referer,
                if (origin.isNotEmpty) 'Origin': origin,
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
              };

              final isM3U8 = mediaUrl.contains('.m3u8') || mediaUrl.contains('/hls/');
              final result = SniffedStreamResult(
                url: mediaUrl,
                headers: headers,
                isM3U8: isM3U8,
                mimeType: getContentType(mediaUrl),
              );
              onMediaFound(result);
            }
          } catch (e) {
            AppLogger.warn('Erro ao decodificar mensagem do sniffer: $e', tag: 'SNIFFER');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            if (isDirectMediaUrl(url)) {
              onMediaFound(SniffedStreamResult(
                url: url,
                isM3U8: url.contains('.m3u8'),
                mimeType: getContentType(url),
              ));
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) {
            controller.runJavaScript(_snifferJsHook).catchError((_) {});
          },
        ),
      );

    return controller;
  }
}
