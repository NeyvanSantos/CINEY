import 'dart:async';
import 'dart:convert';
import 'dart:io';


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
  bool _isPlaying = true;
  double _currentTime = 0;
  double _duration = 0;
  double _volume = 1.0;

  final _commandController = StreamController<String>.broadcast();
  Stream<String> get commandStream => _commandController.stream;

  bool get isRunning => _server != null;
  int get port => _port;
  String? get localIp => _localIp;
  String get tvUrl => 'http://$_localIp:$_port';

  /// Gera a URL local com iframe wrapper para contornar proteções anti-cópia em apps externos (como Web Video Caster)
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
        return true;
      } catch (e2) {
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
  }) {
    _currentTitle = title;
    _currentMediaUrl = mediaUrl;
    _currentPosterUrl = posterUrl;
    _isPlaying = true;
    _currentTime = 0;
    _broadcastCommand(jsonEncode({
      'action': 'load',
      'title': _currentTitle,
      'url': _currentMediaUrl,
      'poster': _currentPosterUrl,
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
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '192.168.1.100';
  }

  void _handleRequest(HttpRequest request) async {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    if (path == '/' || path == '/index.html') {
      // Página do Player da TV
      request.response.headers.contentType = ContentType.html;
      request.response.write(_getTvPlayerHtml());
      await request.response.close();
    } else if (path == '/embed') {
      // Página wrapper com iframe para Web Video Caster / transmissão
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

  String _getTvPlayerHtml() {
    return '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Cinemax TV Receiver</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body, html {
      width: 100vw;
      height: 100vh;
      background: #000;
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
    video, iframe {
      width: 100%;
      height: 100%;
      border: 0;
      object-fit: contain;
    }
    #overlay-header {
      position: absolute;
      top: 30px;
      left: 40px;
      z-index: 100;
      background: rgba(0,0,0,0.6);
      padding: 12px 24px;
      border-radius: 12px;
      backdrop-filter: blur(10px);
      border: 1px solid rgba(255,255,255,0.1);
      transition: opacity 0.5s;
    }
    #overlay-header h1 {
      font-size: 24px;
      color: #00a8ff;
      margin-bottom: 4px;
    }
    #overlay-header p {
      font-size: 14px;
      color: #ccc;
    }
    #idle-screen {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      text-align: center;
    }
    #idle-screen h2 {
      font-size: 36px;
      color: #00a8ff;
      margin-bottom: 12px;
    }
    #idle-screen p {
      font-size: 18px;
      color: #888;
    }
  </style>
</head>
<body>
  <div id="player-container">
    <div id="idle-screen">
      <h2>Cinemax TV</h2>
      <p>Pronto para transmitir. Escolha um filme ou série no celular.</p>
    </div>
  </div>

  <div id="overlay-header" style="display: none;">
    <h1 id="tv-title">Cinemax</h1>
    <p>Transmitindo do celular</p>
  </div>

  <script>
    let currentUrl = '';
    let isEmbed = false;
    let sse = null;

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
        loadMedia(cmd.title, cmd.url);
      } else if (cmd.action === 'play') {
        const vid = document.querySelector('video');
        if (vid) vid.play();
      } else if (cmd.action === 'pause') {
        const vid = document.querySelector('video');
        if (vid) vid.pause();
      } else if (cmd.action === 'seek') {
        const vid = document.querySelector('video');
        if (vid) vid.currentTime = cmd.time;
      } else if (cmd.action === 'volume') {
        const vid = document.querySelector('video');
        if (vid) vid.volume = cmd.value;
      }
    }

    function loadMedia(title, url) {
      currentUrl = url;
      document.getElementById('tv-title').innerText = title;
      document.getElementById('overlay-header').style.display = 'block';
      setTimeout(() => {
        document.getElementById('overlay-header').style.opacity = '0';
      }, 5000);

      const container = document.getElementById('player-container');
      container.innerHTML = '';

      if (url.includes('.mp4') || url.includes('.m3u8')) {
        const video = document.createElement('video');
        video.src = url;
        video.autoplay = true;
        video.controls = true;
        video.style.width = '100%';
        video.style.height = '100%';
        container.appendChild(video);

        video.ontimeupdate = function() {
          fetch('/sync', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              currentTime: video.currentTime,
              duration: video.duration || 0,
              isPlaying: !video.paused
            })
          }).catch(()=>{});
        };
      } else {
        const iframe = document.createElement('iframe');
        iframe.src = url;
        iframe.allow = 'autoplay; fullscreen; encrypted-media';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        container.appendChild(iframe);
      }
    }

    initSSE();
    fetch('/status').then(r => r.json()).then(st => {
      if (st.url) loadMedia(st.title, st.url);
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

