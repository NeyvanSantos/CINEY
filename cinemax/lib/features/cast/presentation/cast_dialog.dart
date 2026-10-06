import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/theme/app_colors.dart';
import '../../../core/services/app_logger.dart';
import '../../../plugin_engine/models/stream_source.dart';
import '../services/media_stream_sniffer.dart';
import '../services/native_cast_bridge.dart';
import '../services/web_cast_server.dart';

class CastDialog extends StatefulWidget {
  final String title;
  final List<StreamSource> sources;
  final VoidCallback? onOpenPlayer;
  final int initialSourceIndex;
  final Duration? startPosition;
  final String? posterUrl;
  final void Function(String deviceName, bool isChromecast)? onCastStarted;

  const CastDialog({
    super.key,
    required this.title,
    this.sources = const [],
    this.onOpenPlayer,
    this.initialSourceIndex = 0,
    this.startPosition,
    this.posterUrl,
    this.onCastStarted,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    List<StreamSource> sources = const [],
    VoidCallback? onOpenPlayer,
    int initialSourceIndex = 0,
    Duration? startPosition,
    String? posterUrl,
    void Function(String deviceName, bool isChromecast)? onCastStarted,
  }) => showDialog<bool>(
    context: context,
    builder: (_) => CastDialog(
      title: title,
      sources: sources,
      onOpenPlayer: onOpenPlayer,
      initialSourceIndex: initialSourceIndex,
      startPosition: startPosition,
      posterUrl: posterUrl,
      onCastStarted: onCastStarted,
    ),
  );

  @override
  State<CastDialog> createState() => _CastDialogState();
}

class _CastDialogState extends State<CastDialog> {
  bool _opening = false;
  bool _isSniffing = false;
  String _sniffingStatus = '';
  String? _error;

  // Seleção de servidor
  int _selectedServerIndex = 0;

  // Timeout visual
  static const int _timeoutSeconds = 45;
  int _remainingSeconds = _timeoutSeconds;
  Timer? _countdownTimer;
  bool _showCountdown = false;

  // Cache de fluxos extraídos por URL
  final Map<String, SniffedStreamResult> _resolvedStreamsCache = {};

  // Sniffer Headless em segundo plano
  WebViewController? _snifferController;
  Completer<SniffedStreamResult?>? _snifferCompleter;

  StreamSource? get _activeSource =>
      widget.sources.isNotEmpty && _selectedServerIndex < widget.sources.length
      ? widget.sources[_selectedServerIndex]
      : null;

  @override
  void initState() {
    super.initState();
    if (widget.sources.isNotEmpty) {
      _selectedServerIndex = widget.initialSourceIndex.clamp(0, widget.sources.length - 1);
    }
    _initSniffer();
  }

  void _initSniffer() {
    _snifferController = MediaStreamSniffer.createSnifferController(
      onMediaFound: (result) {
        if (_activeSource != null) {
          _resolvedStreamsCache[_activeSource!.url] = result;
        }
        if (_snifferCompleter != null && !_snifferCompleter!.isCompleted) {
          _snifferCompleter!.complete(result);
        }
      },
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _remainingSeconds = _timeoutSeconds;
    _showCountdown = true;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _showCountdown = false;
          if (_opening) {
            _opening = false;
            _error =
                'A conexão expirou. Confirme que a TV está ligada no mesmo Wi-Fi.';
          }
        }
      });
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _showCountdown = false;
  }

  /// Resolve a URL direta do stream (utilizando o sniffer se for fonte de embed)
  Future<SniffedStreamResult?> _resolveActiveStream(StreamSource source) async {
    // 1. Verifica se já é link direto de mídia
    if (MediaStreamSniffer.isDirectMediaUrl(source.url)) {
      return SniffedStreamResult(
        url: source.url,
        headers: source.headers ?? const {},
        isM3U8: source.url.contains('.m3u8'),
        mimeType: MediaStreamSniffer.getContentType(source.url),
      );
    }

    // 2. Verifica se já está em cache
    if (_resolvedStreamsCache.containsKey(source.url)) {
      return _resolvedStreamsCache[source.url]!;
    }

    // 3. Executa o sniffer inteligente
    setState(() {
      _isSniffing = true;
      _sniffingStatus = 'Extraindo fluxo de alta definição...';
    });

    _snifferCompleter = Completer<SniffedStreamResult?>();

    try {
      await _snifferController?.loadRequest(Uri.parse(source.url));

      // Aguarda até 9 segundos pela detecção do fluxo de vídeo
      final result = await _snifferCompleter!.future.timeout(
        const Duration(seconds: 9),
        onTimeout: () => null,
      );

      if (result != null) {
        _resolvedStreamsCache[source.url] = result;
        return result;
      }
    } catch (e) {
      AppLogger.warn('Sniffer falhou ao resolver: $e', tag: 'CAST');
    } finally {
      if (mounted) {
        setState(() {
          _isSniffing = false;
          _sniffingStatus = '';
        });
      }
    }

    return null;
  }

  /// Transmite via Google Cast (Chromecast / Google TV nativo)
  Future<void> _openChromecast() async {
    final source = _activeSource;
    if (source == null) {
      setState(
        () => _error = 'Nenhuma fonte de vídeo disponível para transmitir.',
      );
      return;
    }

    setState(() {
      _opening = true;
      _error = null;
    });
    _startCountdown();

    try {
      // 1. Resolve o link real do vídeo
      final streamResult = await _resolveActiveStream(source);
      final rawUrl = streamResult?.url ?? source.url;
      final effectiveHeaders = <String, String>{
        if (source.headers != null) ...source.headers!,
        if (streamResult != null) ...streamResult.headers,
      };

      // Inicia o servidor WebCast para servir o proxy local com CORS
      await WebCastServer.instance.start();

      String targetUrl;
      // Para o Chromecast funcionar de forma 100% infalível:
      // Se houver cabeçalhos anti-hotlink OU se o vídeo for M3U8/HLS, canalizamos pelo
      // proxy local. O proxy injeta os headers CORS e reescreve os segmentos .ts,
      // permitindo que o receiver padrão do Google Cast toque streams de qualquer fonte!
      if (effectiveHeaders.isNotEmpty || rawUrl.contains('.m3u8') || rawUrl.contains('/hls/')) {
        targetUrl = WebCastServer.instance.getProxiedStreamUrl(
          rawUrl,
          headers: effectiveHeaders,
        );
      } else {
        targetUrl = rawUrl;
      }

      final opened = await NativeCastBridge.castMedia(
        url: targetUrl,
        title: widget.title,
        posterUrl: widget.posterUrl,
        startPositionMs: widget.startPosition?.inMilliseconds,
      );

      if (!mounted) return;
      _stopCountdown();

      if (opened) {
        AppLogger.info(
          'Google Cast iniciado com sucesso para $targetUrl',
          tag: 'CAST',
        );
        final deviceName = await NativeCastBridge.castDeviceName() ?? 'Chromecast';
        widget.onCastStarted?.call(deviceName, true);
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _error = 'Transmissão cancelada ou TV não selecionada.';
        });
      }
    } on PlatformException catch (error) {
      AppLogger.warn('Erro na ponte nativa do Cast: ${error.code}', tag: 'CAST');
      if (!mounted) return;
      _stopCountdown();
      setState(() {
        _error = error.message ?? 'Não foi possível conectar ao Chromecast.';
      });
    } catch (error) {
      AppLogger.warn('Erro ao transmitir: $error', tag: 'CAST');
      if (mounted) {
        _stopCountdown();
        setState(() {
          _error = 'Ocorreu um erro ao conectar ao Chromecast.';
        });
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  /// Abre o modo WebCast (Player HTML5 para navegador de qualquer TV)
  Future<void> _openWebCastPlayer() async {
    final source = _activeSource;
    if (source == null) return;

    setState(() {
      _opening = true;
      _error = null;
    });

    try {
      final streamResult = await _resolveActiveStream(source);
      final rawUrl = streamResult?.url ?? source.url;
      final effectiveHeaders = <String, String>{
        if (source.headers != null) ...source.headers!,
        if (streamResult != null) ...streamResult.headers,
      };

      await WebCastServer.instance.start();

      // Se houver headers anti-hotlink ou HLS, roteia pelo proxy local para a TV acessar sem bloqueio
      String effectiveUrl;
      if (effectiveHeaders.isNotEmpty || rawUrl.contains('.m3u8') || rawUrl.contains('/hls/')) {
        effectiveUrl = WebCastServer.instance.getProxiedStreamUrl(rawUrl, headers: effectiveHeaders);
      } else {
        effectiveUrl = rawUrl;
      }

      WebCastServer.instance.updateMedia(
        title: widget.title,
        mediaUrl: effectiveUrl,
        posterUrl: widget.posterUrl,
        headers: effectiveHeaders.isNotEmpty ? effectiveHeaders : null,
        startPositionSeconds: (widget.startPosition?.inMilliseconds ?? 0) / 1000.0,
      );

      widget.onCastStarted?.call('Navegador da TV', false);
      if (!mounted) return;
      _showWebCastInfoModal();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showWebCastInfoModal() {
    final tvUrl = WebCastServer.instance.tvUrl;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, color: AppColors.primary, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Transmissão via Navegador da TV',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Abra o navegador de internet da sua TV (ou de qualquer aparelho na rede) e acesse o endereço abaixo:',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
              ),
              child: SelectableText(
                tvUrl,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: tvUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Endereço copiado para a área de transferência!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar Endereço'),
            ),
            const SizedBox(height: 12),
            const Text(
              'O filme começará a rodar automaticamente na tela da TV assim que você entrar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.surface,
    insetPadding: const EdgeInsets.all(20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Stack(
        children: [
          // WebView invisível off-stage para executar o sniffer de rede
          if (_snifferController != null)
            Offstage(
              offstage: true,
              child: SizedBox(
                width: 1,
                height: 1,
                child: WebViewWidget(controller: _snifferController!),
              ),
            ),

          SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.cast_connected_rounded,
                  color: AppColors.primary,
                  size: 38,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Transmitir para TV',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chromecast / Google TV • WebCast (Link Direto)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                // ── Seletor de Servidor ──
                if (widget.sources.length > 1) ...[
                  const SizedBox(height: 14),
                  _buildServerSelector(),
                ],

                // Indicador de Sniffer em execução
                if (_isSniffing) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _sniffingStatus,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Countdown visual de timeout
                if (_showCountdown && _opening) ...[
                  const SizedBox(height: 12),
                  _buildCountdownIndicator(),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade200,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.red.shade200,
                              height: 1.4,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // ── 1. Botão Principal: Chromecast / Google TV Nativo ──
                FilledButton.icon(
                  onPressed: (_opening || _activeSource == null)
                      ? null
                      : () => _openChromecast(),
                  icon: _opening
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cast_rounded),
                  label: Text(
                    _opening
                        ? 'Conectando...'
                        : 'Chromecast / Google TV',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),

                const SizedBox(height: 10),

                // ── 2. Navegador da TV (WebCast / Link Direto) ──
                OutlinedButton.icon(
                  onPressed: _opening ? null : () => _openWebCastPlayer(),
                  icon: const Icon(Icons.language_rounded, size: 20),
                  label: const Text('Navegador da TV (WebCast / Link Direto)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),

                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _opening
                      ? null
                      : () {
                          final openPlayer = widget.onOpenPlayer;
                          Navigator.of(context).pop();
                          openPlayer?.call();
                        },
                  child: Text(
                    widget.onOpenPlayer == null ? 'Voltar ao filme' : 'Assistir no celular',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildServerSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Escolha o Servidor',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(widget.sources.length, (i) {
            final source = widget.sources[i];
            final isSelected = i == _selectedServerIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _opening
                      ? null
                      : () => setState(() => _selectedServerIndex = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                source.server,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                source.quality,
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCountdownIndicator() {
    final progress = _remainingSeconds / _timeoutSeconds;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              _remainingSeconds <= 10 ? Colors.orange : AppColors.primary,
            ),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _remainingSeconds <= 10
              ? 'Aguardando TV... ($_remainingSeconds s)'
              : 'Conectando ao dispositivo... (${_remainingSeconds}s)',
          style: TextStyle(
            color: _remainingSeconds <= 10
                ? Colors.orange
                : AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
