import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/services/app_logger.dart';

class WebCastServer {
  static final WebCastServer instance = WebCastServer._();
  WebCastServer._();

  HttpServer? _server;
  int _port = 8080;
  String? _localIp;

  // Estado atual do player na TV
  String _currentTitle = 'Cinemax';
  String _currentMediaUrl = '';
  String? _currentPosterUrl;
  Map<String, String> _currentHeaders = {};
  bool _isPlaying = true;
  double _currentTime = 0;
  double _duration = 0;
  double _volume = 1.0;

  final _commandController = StreamController<String>.broadcast();
  Stream<String> get commandStream => _commandController.stream;

  bool get isRunning => _server != null;
  int get port => _port;
  String? get localIp => _localIp;
  String get tvUrl => 'http://${_localIp ?? "127.0.0.1"}:$_port';
  bool get isPlaying => _isPlaying;
  double get currentTime => _currentTime;
  double get duration => _duration;
  double get volume => _volume;

  /// Gera a URL local com proxy HLS / HTTP para contornar bloqueios de CORS e Referer nas Smart TVs
  String getProxiedStreamUrl(String rawMediaUrl, {Map<String, String>? headers}) {
    final host = _localIp ?? '127.0.0.1';
    final queryParams = <String, String>{
      'url': rawMediaUrl,
    };
    if (headers != null) {
      if (headers['Referer'] != null) queryParams['referer'] = headers['Referer']!;
      if (headers['Origin'] != null) queryParams['origin'] = headers['Origin']!;
      if (headers['User-Agent'] != null) queryParams['ua'] = headers['User-Agent']!;
    }
    final uri = Uri(
      scheme: 'http',
      host: host,
      port: _port,
      path: '/stream',
      queryParameters: queryParams,
    );
    return uri.toString();
  }

  /// Gera a URL local com iframe wrapper para transmissões Web
  String getEmbedUrl(String rawEmbedUrl, {bool useLocalhost = true}) {
    final host = useLocalhost ? '127.0.0.1' : (_localIp ?? '127.0.0.1');
    return 'http://$host:$_port/embed?url=${Uri.encodeComponent(rawEmbedUrl)}';
  }

  Future<bool> start({int port = 8080}) async {
    if (_server != null) return true;
    _port = port;

    try {
      _localIp = await _getLocalIpAddress();
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        _port,
        shared: true,
      );

      _server!.listen(_handleRequest);
      AppLogger.info('WebCastServer iniciado em http://$_localIp:$_port', tag: 'WEBCAST');
      return true;
    } catch (e) {
      try {
        // Tenta porta alternativa
        _port = 8088;
        _server = await HttpServer.bind(
          InternetAddress.anyIPv4,
          _port,
          shared: true,
        );
        _server!.listen(_handleRequest);
        AppLogger.info('WebCastServer iniciado na porta alternativa http://$_localIp:$_port', tag: 'WEBCAST');
        return true;
      } catch (e2) {
        AppLogger.warn('Erro ao iniciar WebCastServer: $e2', tag: 'WEBCAST');
        return false;
      }
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void updateMedia({
    required String title,
    required String mediaUrl,
    String? posterUrl,
    Map<String, String>? headers,
    double startPositionSeconds = 0,
  }) {
    _currentTitle = title;
    _currentMediaUrl = mediaUrl;
    _currentPosterUrl = posterUrl;
    if (headers != null) _currentHeaders = Map.from(headers);
    _isPlaying = true;
    _currentTime = startPositionSeconds;
    _broadcastCommand(jsonEncode({
      'action': 'load',
      'title': _currentTitle,
      'url': _currentMediaUrl,
      'poster': _currentPosterUrl,
      'startTime': startPositionSeconds,
    }));
  }

  void play() {
    _isPlaying = true;
    _broadcastCommand(jsonEncode({'action': 'play'}));
  }

  void pause() {
    _isPlaying = false;
    _broadcastCommand(jsonEncode({'action': 'pause'}));
  }

  void seekTo(double seconds) {
    _currentTime = seconds;
    _broadcastCommand(jsonEncode({'action': 'seek', 'time': seconds}));
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _broadcastCommand(jsonEncode({'action': 'volume', 'value': _volume}));
  }

  void _broadcastCommand(String command) {
    _commandController.add(command);
  }

  Future<String> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // Prioridade 1: interface Wi-Fi / Ethernet comum em smartphones Android
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('eth') || name.contains('en') || name.contains('wl')) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback && !addr.address.startsWith('127.')) {
              return addr.address;
            }
          }
        }
      }

      // Prioridade 2: Sub-rede doméstica padrão 192.168.x.x
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.address.startsWith('192.168.')) {
            return addr.address;
          }
        }
      }

      // Prioridade 3: Qualquer endereço IPv4 válido não-loopback
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '192.168.1.100';
  }

  void _handleRequest(HttpRequest request) async {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, HEAD, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    if (path == '/' || path == '/index.html') {
      // Página do Player da TV (Clappr + HLS.js integrado)
      request.response.headers.contentType = ContentType.html;
      request.response.write(_getTvPlayerHtml());
      await request.response.close();
    } else if (path == '/stream') {
      // Proxy HTTP / HLS com injeção de headers e suporte a Range
      await _handleStreamProxy(request);
    } else if (path == '/embed') {
      // Página wrapper com iframe
      final targetUrl = request.uri.queryParameters['url'] ?? _currentMediaUrl;
      request.response.headers.contentType = ContentType.html;
      request.response.headers.set('Cache-Control', 'no-cache');
      request.response.write(_getEmbedWrapperHtml(targetUrl));
      await request.response.close();
    } else if (path == '/status') {
      // Retorna estado atual
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'title': _currentTitle,
        'url': _currentMediaUrl,
        'poster': _currentPosterUrl,
        'isPlaying': _isPlaying,
        'currentTime': _currentTime,
        'duration': _duration,
        'volume': _volume,
      }));
      await request.response.close();
    } else if (path == '/events') {
      // Server-Sent Events (SSE) para atualização em tempo real na TV
      request.response.headers.set('Content-Type', 'text/event-stream');
      request.response.headers.set('Cache-Control', 'no-cache');
      request.response.headers.set('Connection', 'keep-alive');

      final subscription = commandStream.listen((cmd) {
        try {
          request.response.write('data: $cmd\n\n');
        } catch (_) {}
      });

      request.response.done.then((_) => subscription.cancel());
    } else if (path == '/sync' && request.method == 'POST') {
      // A TV envia o tempo atual e duração de volta para o celular
      final body = await utf8.decodeStream(request);
      try {
        final data = jsonDecode(body) as Map<String, dynamic>;
        _currentTime = (data['currentTime'] as num?)?.toDouble() ?? _currentTime;
        _duration = (data['duration'] as num?)?.toDouble() ?? _duration;
        _isPlaying = (data['isPlaying'] as bool?) ?? _isPlaying;
      } catch (_) {}
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  /// Proxy retransmissor de fluxo de mídia (HLS-Proxy)
  Future<void> _handleStreamProxy(HttpRequest request) async {
    final targetUrl = request.uri.queryParameters['url'];
    if (targetUrl == null || targetUrl.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('URL de mídia não informada.');
      await request.response.close();
      return;
    }

    final referer = request.uri.queryParameters['referer'] ?? _currentHeaders['Referer'];
    final origin = request.uri.queryParameters['origin'] ?? _currentHeaders['Origin'];
    final userAgent = request.uri.queryParameters['ua'] ??
        _currentHeaders['User-Agent'] ??
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    final client = HttpClient()..autoUncompress = false;

    try {
      final clientReq = await client.getUrl(Uri.parse(targetUrl));

      // Repassa Range request da TV
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        clientReq.headers.set(HttpHeaders.rangeHeader, range);
      }

      // Adiciona cabeçalhos anti-bloqueio
      if (referer != null && referer.isNotEmpty) {
        clientReq.headers.set(HttpHeaders.refererHeader, referer);
      }
      if (origin != null && origin.isNotEmpty) {
        clientReq.headers.set('Origin', origin);
      }
      clientReq.headers.set(HttpHeaders.userAgentHeader, userAgent);

      final clientRes = await clientReq.close();

      request.response.statusCode = clientRes.statusCode;

      // Propaga cabeçalhos úteis mantendo CORS aberto
      clientRes.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (lower != 'access-control-allow-origin' &&
            lower != 'access-control-allow-methods' &&
            lower != 'access-control-allow-headers') {
          for (var v in values) {
            request.response.headers.add(name, v);
          }
        }
      });

      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      request.response.headers.set('Access-Control-Allow-Headers', '*');

      // Para playlists HLS (.m3u8), reescreve URLs dos segmentos para passarem pelo proxy
      final isM3u8 = targetUrl.contains('.m3u8') ||
          (clientRes.headers.contentType?.mimeType.contains('mpegurl') ?? false) ||
          (clientRes.headers.contentType?.mimeType.contains('mpegURL') ?? false);

      if (isM3u8) {
        request.response.headers.set('Content-Type', 'application/vnd.apple.mpegurl');
        final body = await utf8.decodeStream(clientRes);
        final rewritten = _rewriteM3u8(body, targetUrl, referer, origin, userAgent);
        request.response.write(rewritten);
        await request.response.close();
      } else {
        await clientRes.pipe(request.response);
      }
    } catch (e) {
      AppLogger.warn('Erro no proxy de streaming: $e', tag: 'PROXY');
      try {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      } catch (_) {}
    } finally {
      client.close();
    }
  }

  /// Reescreve URLs dentro de uma playlist M3U8 para serem canalizadas pelo proxy local.
  /// Isso garante que segmentos .ts, sub-playlists, e chaves de DRM passem pelo proxy
  /// com os headers anti-hotlink corretos.
  String _rewriteM3u8(String content, String baseUrl, String? referer, String? origin, String userAgent) {
    final baseUri = Uri.parse(baseUrl);
    final lines = content.split('\n');
    final result = StringBuffer();

    for (final line in lines) {
      final trimmed = line.trim();

      // Linhas de comentário/diretivas: passar direto, exceto URI= em #EXT-X-KEY
      if (trimmed.startsWith('#')) {
        if (trimmed.contains('URI="')) {
          // Reescreve URI de chaves de criptografia
          final rewritten = trimmed.replaceAllMapped(
            RegExp(r'URI="([^"]+)"'),
            (match) {
              final keyUrl = _resolveUrl(match.group(1)!, baseUri);
              final proxied = _buildProxyUrl(keyUrl, referer, origin, userAgent);
              return 'URI="$proxied"';
            },
          );
          result.writeln(rewritten);
        } else {
          result.writeln(trimmed);
        }
        continue;
      }

      // Linhas vazias
      if (trimmed.isEmpty) {
        result.writeln();
        continue;
      }

      // Linhas de dados (URLs de segmento ou sub-playlist)
      final segmentUrl = _resolveUrl(trimmed, baseUri);
      final proxied = _buildProxyUrl(segmentUrl, referer, origin, userAgent);
      result.writeln(proxied);
    }

    return result.toString();
  }

  /// Resolve uma URL relativa contra a URL base
  String _resolveUrl(String url, Uri baseUri) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return baseUri.resolve(url).toString();
  }

  /// Constrói a URL do proxy local com os parâmetros de header
  String _buildProxyUrl(String targetUrl, String? referer, String? origin, String userAgent) {
    final host = _localIp ?? '127.0.0.1';
    final params = <String, String>{'url': targetUrl};
    if (referer != null && referer.isNotEmpty) params['referer'] = referer;
    if (origin != null && origin.isNotEmpty) params['origin'] = origin;
    params['ua'] = userAgent;
    return Uri(scheme: 'http', host: host, port: _port, path: '/stream', queryParameters: params).toString();
  }


  String _getTvPlayerHtml() {
    return '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Cinemax TV Receiver</title>
  <!-- Suporte nativo a HLS.js para TVs modernas (LG webOS, Samsung Tizen) -->
  <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body, html {
      width: 100vw;
      height: 100vh;
      background: #05070a;
      color: #fff;
      font-family: 'Segoe UI', Roboto, sans-serif;
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    #player-container {
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #000;
    }
    video {
      width: 100%;
      height: 100%;
      object-fit: contain;
      background: #000;
    }
    #overlay-header {
      position: absolute;
      top: 32px;
      left: 40px;
      z-index: 100;
      background: rgba(10, 15, 25, 0.85);
      padding: 14px 28px;
      border-radius: 14px;
      backdrop-filter: blur(12px);
      border: 1px solid rgba(0, 168, 255, 0.3);
      box-shadow: 0 8px 32px rgba(0,0,0,0.5);
      transition: opacity 0.6s ease;
      pointer-events: none;
    }
    #overlay-header h1 {
      font-size: 24px;
      color: #00a8ff;
      margin-bottom: 4px;
      font-weight: 700;
    }
    #overlay-header p {
      font-size: 14px;
      color: #a0aec0;
    }
    #idle-screen {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      text-align: center;
      padding: 30px;
    }
    .badge {
      display: inline-block;
      padding: 6px 16px;
      background: rgba(0, 168, 255, 0.15);
      border: 1px solid #00a8ff;
      border-radius: 50px;
      color: #00a8ff;
      font-size: 14px;
      font-weight: 600;
      margin-bottom: 20px;
      text-transform: uppercase;
      letter-spacing: 1px;
    }
    #idle-screen h2 {
      font-size: 44px;
      font-weight: 800;
      color: #ffffff;
      margin-bottom: 14px;
      letter-spacing: -0.5px;
    }
    #idle-screen p {
      font-size: 20px;
      color: #718096;
      max-width: 600px;
      line-height: 1.5;
    }
    .tv-ip-box {
      margin-top: 36px;
      padding: 16px 32px;
      background: rgba(255,255,255,0.03);
      border: 1px dashed rgba(255,255,255,0.2);
      border-radius: 12px;
      font-size: 16px;
      color: #cbd5e0;
    }
    .tv-ip-box strong {
      color: #00a8ff;
      font-size: 18px;
    }
  </style>
</head>
<body>
  <div id="player-container">
    <div id="idle-screen">
      <div class="badge">Receptor de Transmissão</div>
      <h2>CineMax TV</h2>
      <p>Pronto para reproduzir. Escolha qualquer título no aplicativo do celular e clique em Transmitir.</p>
      <div class="tv-ip-box">
        Endereço desta TV: <strong>http://$_localIp:$_port</strong>
      </div>
    </div>
  </div>

  <div id="overlay-header" style="display: none;">
    <h1 id="tv-title">Cinemax</h1>
    <p>Transmitindo em alta definição</p>
  </div>

  <script>
    let hls = null;
    let sse = null;
    let videoEl = null;

    function initSSE() {
      sse = new EventSource('/events');
      sse.onmessage = function(event) {
        try {
          const data = JSON.parse(event.data);
          handleCommand(data);
        } catch(e) {}
      };
      sse.onerror = function() {
        setTimeout(initSSE, 3000);
      };
    }

    function handleCommand(cmd) {
      if (cmd.action === 'load') {
        loadMedia(cmd.title, cmd.url, cmd.poster, cmd.startTime || 0);
      } else if (cmd.action === 'play') {
        if (videoEl) videoEl.play();
      } else if (cmd.action === 'pause') {
        if (videoEl) videoEl.pause();
      } else if (cmd.action === 'seek') {
        if (videoEl) videoEl.currentTime = cmd.time;
      } else if (cmd.action === 'volume') {
        if (videoEl) videoEl.volume = cmd.value;
      }
    }

    function loadMedia(title, url, poster, startTime = 0) {
      document.getElementById('tv-title').innerText = title;
      const header = document.getElementById('overlay-header');
      header.style.display = 'block';
      header.style.opacity = '1';
      setTimeout(() => {
        header.style.opacity = '0';
      }, 6000);

      const container = document.getElementById('player-container');
      container.innerHTML = '';

      videoEl = document.createElement('video');
      videoEl.autoplay = true;
      videoEl.controls = true;
      if (poster) videoEl.poster = poster;

      container.appendChild(videoEl);

      function applyStartTime() {
        if (startTime > 0) {
          try { videoEl.currentTime = startTime; } catch(e) {}
        }
      }

      if (hls) {
        hls.destroy();
        hls = null;
      }

      if (url.includes('.m3u8')) {
        if (Hls.isSupported()) {
          hls = new Hls({ enableWorker: true, lowLatencyMode: true });
          hls.loadSource(url);
          hls.attachMedia(videoEl);
          hls.on(Hls.Events.MANIFEST_PARSED, function() {
            applyStartTime();
            videoEl.play().catch(()=>{});
          });
        } else if (videoEl.canPlayType('application/vnd.apple.mpegurl')) {
          videoEl.src = url;
          videoEl.addEventListener('loadedmetadata', applyStartTime, { once: true });
          videoEl.play().catch(()=>{});
        }
      } else {
        videoEl.src = url;
        videoEl.addEventListener('loadedmetadata', applyStartTime, { once: true });
        videoEl.play().catch(()=>{});
      }

      videoEl.ontimeupdate = function() {
        fetch('/sync', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            currentTime: videoEl.currentTime,
            duration: videoEl.duration || 0,
            isPlaying: !videoEl.paused
          })
        }).catch(()=>{});
      };
    }

    initSSE();
    fetch('/status').then(r => r.json()).then(st => {
      if (st.url) loadMedia(st.title, st.url, st.poster);
    }).catch(()=>{});
  </script>
</body>
</html>
''';
  }

  String _getEmbedWrapperHtml(String targetUrl) {
    final escapedUrl = const HtmlEscape(HtmlEscapeMode.attribute).convert(targetUrl);
    return '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <meta name="referrer" content="no-referrer">
  <title>Cinemax Cast Player</title>
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      background: #000;
      overflow: hidden;
    }
    iframe {
      display: block;
      width: 100%;
      height: 100%;
      border: 0;
    }
  </style>
</head>
<body>
  <iframe
    id="cinemax-player"
    src="$escapedUrl"
    title="Cinemax Player"
    frameborder="0"
    scrolling="no"
    allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
    allowfullscreen
    referrerpolicy="no-referrer">
  </iframe>
</body>
</html>''';
  }
}
