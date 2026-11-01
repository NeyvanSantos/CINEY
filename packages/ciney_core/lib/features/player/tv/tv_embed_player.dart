import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'tv_embed_host.dart';
import '../../../core/services/app_logger.dart';
import '../../../plugin_engine/models/stream_source.dart';
import 'tv_embed_document.dart';
import 'tv_webview_bridge.dart';
import 'tv_hls_candidate.dart';

/// One visible WebView. The provider owns playback, progress and media controls.
class TvEmbedPlayer extends StatefulWidget {
  const TvEmbedPlayer({
    super.key,
    required this.source,
    required this.title,
    required this.onExit,
    required this.onSources,
    this.onNext,
    this.allowExit = false,
    this.createHost = TvEmbedHost.new,
    this.onMedia,
  });
  final StreamSource source;
  final String title;
  final VoidCallback onExit;
  final VoidCallback onSources;
  final VoidCallback? onNext;
  final bool allowExit;
  final TvEmbedHost Function() createHost;

  /// Keeps the provider available if native initialization fails.
  final Future<bool> Function(StreamSource, bool Function())? onMedia;

  @override
  State<TvEmbedPlayer> createState() => _TvEmbedPlayerState();
}

class _TvEmbedPlayerState extends State<TvEmbedPlayer>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  TvEmbedHost? _host;
  int? _viewId;
  int _generation = 0;
  bool _loading = true;
  bool _menu = false;
  bool _suspended = false;
  bool _resolvingMedia = false;
  final _attemptedMedia = <String>{};
  String? _message;
  Widget? _fullscreen;
  VoidCallback? _hideFullscreen;
  Timer? _deadline;
  Timer? _menuDeadline;
  StreamSubscription<({int id, String action})>? _events;
  final _menuFocus = FocusNode(debugLabel: 'TV provider menu');
  final _browserFocus = FocusNode(debugLabel: 'TV browser keys');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events = TvWebViewBridge.events.listen((event) {
      if (event.id != _viewId || !mounted) return;
      if (event.action == 'back') {
        _back();
      } else {
        _showMenu();
      }
    });
    unawaited(_open());
  }

  bool _current(int generation) => mounted && generation == _generation;

  Future<void> _release() async {
    _deadline?.cancel();
    _menuDeadline?.cancel();
    final host = _host;
    _host = null;
    _controller = null;
    _viewId = null;
    _closeFullscreen();
    try {
      await host?.release();
    } catch (_) {
      AppLogger.warn(
        'WebView já encerrada durante liberação.',
        tag: 'TV_ENGINE',
      );
    }
  }

  Future<void> _open() async {
    final generation = ++_generation;
    final documentBaseUrl = tvEmbedBaseUrlFor(widget.source.url);
    await _release();
    if (!_current(generation)) return;
    setState(() {
      _loading = true;
      _menu = false;
      _message = null;
      _suspended = false;
      _resolvingMedia = false;
      _attemptedMedia.clear();
    });
    _deadline = Timer(const Duration(seconds: 25), () {
      if (!_current(generation)) return;
      setState(() {
        _loading = false;
        _message =
            'O servidor não concluiu a abertura. Tente novamente ou troque de servidor.';
      });
      _showMenu();
    });
    try {
      final host = widget.createHost();
      _host = host;
      final controller = host.controller;
      _controller = controller;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (!_current(generation)) return;
      await controller.setBackgroundColor(Colors.black);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            // The provider remains inside its frame; do not launch external apps/popups.
            if (request.isMainFrame &&
                request.url != documentBaseUrl &&
                request.url != 'about:blank' &&
                uri?.scheme != 'data') {
              return NavigationDecision.prevent;
            }
            return const [
                  'https',
                  'http',
                  'about',
                  'data',
                  'blob',
                ].contains(uri?.scheme)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            if (!_current(generation) || _suspended || _message != null) return;
            if (widget.onMedia == null) {
              _deadline?.cancel();
              setState(() => _loading = false);
            }
            AppLogger.info(
              'Documento do provedor aberto; reprodução depende do player original.',
              tag: 'TV_ENGINE',
            );
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && _current(generation)) {
              _fail(
                'Não foi possível abrir o player. Verifique a conexão ou troque de servidor.',
              );
            }
          },
          onHttpError: (error) {
            // Subresource failures can be ads/telemetry, not a playback failure.
            if ((error.request?.uri.toString() == documentBaseUrl ||
                    error.request?.uri.toString() == widget.source.url) &&
                _current(generation)) {
              _fail(
                'O servidor recusou a abertura do player. Tente outro servidor.',
              );
            }
          },
        ),
      );
      if (!_current(generation)) return;
      _viewId = host.viewId;
      if (_viewId != null) await TvWebViewBridge.invoke('attach', _viewId!);
      if (!_current(generation)) return;
      await host.configure(
        onFullscreen: (view, onHide) {
          if (!_current(generation)) {
            onHide();
            return;
          }
          setState(() {
            _fullscreen = view;
            _hideFullscreen = onHide;
            _menu = false;
          });
        },
        onHideFullscreen: () {
          if (!_current(generation)) return;
          setState(() {
            _fullscreen = null;
            _hideFullscreen = null;
          });
        },
      );
      if (!_current(generation)) return;
      if (widget.onMedia != null) {
        final observing = await host.observeHls(
          widget.source,
          (candidate) => unawaited(_openMedia(candidate, generation, host)),
          onMenuState: (action) {
            if (!_current(generation) || _suspended || _resolvingMedia) return;
            _deadline?.cancel();
            setState(() {
              _loading = action == 'selected';
              _message = null;
            });
            if (action == 'ready') _focusProvider();
            if (action == 'selected') {
              _deadline = Timer(const Duration(seconds: 25), () {
                if (_current(generation) && !_resolvingMedia) {
                  _fail(
                    'O servidor não iniciou o vídeo. Recarregue ou escolha outro servidor.',
                  );
                }
              });
            }
          },
        );
        if (!_current(generation)) return;
        AppLogger.info(
          observing
              ? 'Aguardando playlist HLS do servidor.'
              : 'WebView sem observação HLS; use os controles do servidor.',
          tag: 'TV_ENGINE',
        );
      }
      setState(() {});
      await controller.loadHtmlString(
        buildTvEmbedDocument(widget.source.url),
        baseUrl: documentBaseUrl,
      );
      if (_current(generation)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_current(generation) && !_menu) _focusProvider();
        });
      }
    } catch (error) {
      if (!_current(generation)) return;
      AppLogger.warn(
        'Falha na inicialização do player (${error.runtimeType}).',
        tag: 'TV_ENGINE',
      );
      _fail(
        'Não foi possível iniciar o player. Recarregue ou escolha outro servidor.',
      );
    }
  }

  Future<void> _openMedia(
    TvHlsCandidate candidate,
    int generation,
    TvEmbedHost host,
  ) async {
    if (!_current(generation) ||
        _suspended ||
        _resolvingMedia ||
        _attemptedMedia.contains(candidate.url)) {
      return;
    }
    _attemptedMedia.add(candidate.url);
    _resolvingMedia = true;
    _deadline?.cancel();
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final headers = await host.playbackHeaders(candidate.url);
      if (!_current(generation) || _suspended) return;
      AppLogger.info(
        'Playlist HLS encontrada; preparando vídeo.',
        tag: 'TV_ENGINE',
      );
      final playing = await widget.onMedia!(
        candidate.toSource(widget.source, headers),
        () => _current(generation) && !_suspended,
      );
      if (!_current(generation) || _suspended) return;
      if (playing) {
        await _release();
      } else {
        _fail(
          'Não foi possível reproduzir o vídeo deste servidor. '
          'Recarregue ou escolha outro servidor.',
        );
      }
    } catch (error) {
      if (!_current(generation) || _suspended) return;
      AppLogger.warn(
        'Falha ao preparar HLS (${error.runtimeType}).',
        tag: 'TV_ENGINE',
      );
      _fail(
        'Não foi possível preparar o vídeo. Recarregue ou troque de servidor.',
      );
    } finally {
      if (_current(generation)) _resolvingMedia = false;
    }
  }

  void _fail(String message) {
    _deadline?.cancel();
    setState(() {
      _loading = false;
      _message = message;
    });
    _showMenu();
  }

  void _closeFullscreen() {
    final hide = _hideFullscreen;
    _hideFullscreen = null;
    _fullscreen = null;
    hide?.call();
  }

  void _showMenu() {
    if (!mounted) return;
    setState(() {
      _closeFullscreen();
      _menu = true;
    });
    _renewMenuDeadline();
    final id = _viewId;
    if (id != null) unawaited(TvWebViewBridge.invoke('blur', id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _menu) _menuFocus.requestFocus();
    });
  }

  void _back() {
    if (_fullscreen != null) {
      setState(_closeFullscreen);
      _showMenu();
    } else if (!_menu) {
      _showMenu();
    } else {
      widget.onExit();
    }
  }

  void _focusProvider() {
    _menuDeadline?.cancel();
    setState(() => _menu = false);
    _browserFocus.requestFocus();
    final id = _viewId;
    if (id != null) unawaited(TvWebViewBridge.invoke('focus', id));
  }

  void _renewMenuDeadline() {
    _menuDeadline?.cancel();
    // Keep recovery actions available when there is no live provider to return to.
    if (!_menu || _suspended || _controller == null) return;
    _menuDeadline = Timer(const Duration(seconds: 5), () {
      if (mounted && _menu && !_suspended && _controller != null) {
        _focusProvider();
      }
    });
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_menu) _renewMenuDeadline();
    if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      _showMenu();
      return KeyEventResult.handled;
    }
    if (_menu) return KeyEventResult.ignored;
    final code = <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.arrowUp: 19,
      LogicalKeyboardKey.arrowDown: 20,
      LogicalKeyboardKey.arrowLeft: 21,
      LogicalKeyboardKey.arrowRight: 22,
      LogicalKeyboardKey.select: 23,
      LogicalKeyboardKey.enter: 66,
      LogicalKeyboardKey.mediaPlayPause: 85,
      LogicalKeyboardKey.mediaStop: 86,
      LogicalKeyboardKey.mediaPlay: 126,
      LogicalKeyboardKey.mediaPause: 127,
    }[event.logicalKey];
    final id = _viewId;
    if (code == null || id == null) return KeyEventResult.ignored;
    unawaited(TvWebViewBridge.invoke('key', id, keyCode: code));
    return KeyEventResult.handled;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // onMedia remains pending for the whole dedicated Activity session. Its
    // WebView supplies authenticated segments even while Flutter is paused.
    if (_resolvingMedia) return;
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden) {
      return;
    }
    if (_suspended) return;
    ++_generation;
    unawaited(_release());
    setState(() {
      _suspended = true;
      _loading = false;
      _menu = true;
      _message =
          'Reprodução interrompida ao sair do app. Selecione Recarregar para continuar.';
    });
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    unawaited(_release());
    _menuFocus.dispose();
    _browserFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.allowExit,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _browserFocus,
        onKeyEvent: _key,
        child: Listener(
          onPointerDown: (_) => _menuDeadline?.cancel(),
          onPointerUp: (_) => _renewMenuDeadline(),
          onPointerCancel: (_) => _renewMenuDeadline(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_controller != null && !_suspended)
                WebViewWidget(controller: _controller!),
              ?_fullscreen,
              if (_loading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
              if (_menu)
                Align(
                  alignment: Alignment.topCenter,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.94),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.title} • ${widget.source.server}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _message ??
                                'Use as setas e OK no player. Voltar ou Menu abre estas opções. Se ficar sem imagem, recarregue ou troque de servidor.',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              FilledButton(
                                focusNode: _menuFocus,
                                autofocus: true,
                                onPressed: _suspended || _controller == null
                                    ? () => unawaited(_open())
                                    : _focusProvider,
                                child: Text(
                                  _suspended || _controller == null
                                      ? 'Recarregar'
                                      : 'Ir ao player',
                                ),
                              ),
                              if (!_suspended && _controller != null)
                                OutlinedButton(
                                  onPressed: () => unawaited(_open()),
                                  child: const Text('Recarregar'),
                                ),
                              OutlinedButton(
                                onPressed: widget.onSources,
                                child: const Text('Servidores'),
                              ),
                              if (widget.onNext != null)
                                OutlinedButton(
                                  onPressed: widget.onNext,
                                  child: const Text('Próximo episódio'),
                                ),
                              OutlinedButton(
                                onPressed: widget.onExit,
                                child: const Text('Sair'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
