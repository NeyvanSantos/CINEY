import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/theme/app_colors.dart';
import '../../../core/services/app_logger.dart';
import '../../../plugin_engine/models/stream_source.dart';
import '../models/cast_device.dart';
import '../services/dlna_discovery_service.dart';
import '../services/native_cast_bridge.dart';
import '../services/universal_cast_service.dart';
import '../services/web_cast_server.dart';

class CastDialog extends StatefulWidget {
  final String title;
  final List<StreamSource> sources;
  final VoidCallback? onOpenPlayer;

  const CastDialog({
    super.key,
    required this.title,
    this.sources = const [],
    this.onOpenPlayer,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    List<StreamSource> sources = const [],
    VoidCallback? onOpenPlayer,
  }) => showDialog<void>(
    context: context,
    builder: (_) => CastDialog(
      title: title,
      sources: sources,
      onOpenPlayer: onOpenPlayer,
    ),
  );

  @override
  State<CastDialog> createState() => _CastDialogState();
}

class _CastDialogState extends State<CastDialog> {
  bool _opening = false;
  bool _webVideoCasterMissing = false;
  String? _error;

  // Server selection
  int _selectedServerIndex = 0;

  // Timeout visual
  static const int _timeoutSeconds = 60;
  int _remainingSeconds = _timeoutSeconds;
  Timer? _countdownTimer;
  bool _showCountdown = false;

  // DLNA Discovery
  final _dlnaService = DlnaDiscoveryService.instance;
  final _castService = UniversalCastService();
  List<CastDevice> _dlnaDevices = [];
  StreamSubscription<List<CastDevice>>? _devicesSub;
  bool _isScanning = false;

  StreamSource? get _activeSource =>
      widget.sources.isNotEmpty && _selectedServerIndex < widget.sources.length
          ? widget.sources[_selectedServerIndex]
          : null;

  @override
  void initState() {
    super.initState();
    _startDlnaScan();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _devicesSub?.cancel();
    _dlnaService.stopDiscovery();
    super.dispose();
  }

  void _startDlnaScan() {
    setState(() => _isScanning = true);
    _devicesSub = _dlnaService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() => _dlnaDevices = devices);
      }
    });
    _dlnaService.startDiscovery(timeout: const Duration(seconds: 15)).then((_) {
      if (mounted) setState(() => _isScanning = false);
    });
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
            _error = 'A conexão expirou. Confirme que os aparelhos estão no mesmo Wi-Fi.';
          }
        }
      });
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _showCountdown = false;
  }

  Future<void> _openCastDevice() async {
    final source = _activeSource;
    if (source == null) {
      setState(() => _error = 'Nenhuma fonte de vídeo disponível para transmitir.');
      return;
    }

    setState(() {
      _opening = true;
      _error = null;
    });
    _startCountdown();

    try {
      var opened = false;
      final url = source.url;
      if (NativeCastBridge.isDirectMediaUrl(url)) {
        opened = await NativeCastBridge.castMedia(url: url, title: widget.title);
      } else {
        // Para fontes de embed (iframe):
        // Inicia o WebCastServer local para servir a página com iframe wrapper.
        // Isso garante que a requisição ocorra dentro de um iframe legítimo (Sec-Fetch-Dest: iframe),
        // contornando a camuflagem anti-cópia que exibia a página "Investidor.blog".
        await WebCastServer.instance.start();
        final targetUrl = WebCastServer.instance.getEmbedUrl(url);
        opened = await NativeCastBridge.openWebVideoCaster(
          url: targetUrl,
          title: widget.title,
        );
      }

      if (!mounted) return;
      _stopCountdown();
      setState(() {
        if (!opened) {
          _error = _webVideoCasterMissing
              ? 'Instale o Web Video Caster para transmitir esta fonte.'
              : 'Não foi possível abrir o transmissor.';
        }
      });
      if (opened) {
        AppLogger.info(
          'Transmissão via ${source.server} aberta. Fonte: ${source.url}',
          tag: 'CAST',
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } on PlatformException catch (error) {
      AppLogger.warn(
        'Falha ao abrir seleção de TV: ${error.code}',
        tag: 'CAST',
      );
      if (!mounted) return;
      _stopCountdown();
      setState(() {
        _webVideoCasterMissing = error.code == 'WEB_VIDEO_CASTER_NOT_INSTALLED';
        _error = error.message ?? 'Não foi possível abrir o seletor de TV.';
      });
    } catch (error) {
      AppLogger.warn('Transmissão indisponível: $error', tag: 'CAST');
      if (mounted) {
        _stopCountdown();
        setState(
          () => _error = 'Não foi possível abrir o Chromecast neste aparelho.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _castViaDlna(CastDevice device) async {
    final source = _activeSource;
    if (source == null) {
      setState(() => _error = 'Nenhuma URL de mídia disponível para DLNA.');
      return;
    }

    if (!NativeCastBridge.isDirectMediaUrl(source.url)) {
      setState(() => _error = 'Fontes de Embed precisam do botão "Web Video Caster / Chromecast" para transmitir para a TV.');
      return;
    }

    setState(() {
      _opening = true;
      _error = null;
    });

    try {
      final success = await _castService.connectAndCast(
        device: device,
        title: widget.title,
        mediaUrl: source.url,
      );

      if (!mounted) return;
      if (success) {
        AppLogger.info(
          'DLNA: Transmissão iniciada para ${device.name} via ${source.server}',
          tag: 'CAST',
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        setState(() => _error = 'A TV "${device.name}" não aceitou a transmissão DLNA.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Erro ao transmitir via DLNA: $e');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.surface,
    insetPadding: const EdgeInsets.all(20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.screen_share_rounded,
              color: AppColors.primary,
              size: 36,
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
            const SizedBox(height: 6),
            const Text(
              'Chromecast / Google TV / DLNA',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              maxLines: 2,
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

            const SizedBox(height: 10),
            const Text(
              'Fontes Embed (EmbedMovies e SuperFlix) serão abertas diretamente no Web Video Caster para você escolher a TV, sem espelhamento de tela.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            _step('1', 'Conecte o celular e a TV à mesma rede Wi‑Fi.'),
            _step(
              '2',
              'A TV aparecerá automaticamente na seleção do Chromecast. Escolha sua TV.',
            ),
            _step(
              '3',
              'Quando a TV estiver conectada, o app envia o vídeo para a reprodução na televisão.',
            ),
            _step(
              '4',
              'Mantenha o celular desbloqueado enquanto a reprodução estiver na TV.',
            ),

            // Countdown visual de timeout
            if (_showCountdown && _opening) ...[
              const SizedBox(height: 10),
              _buildCountdownIndicator(),
            ],

            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade200, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade200, height: 1.4, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Botão principal: Chromecast / WVC
            FilledButton.icon(
              onPressed: (_opening || _activeSource == null) ? null : () => _openCastDevice(),
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
                    : _activeSource != null
                        ? 'Transmitir via ${_activeSource!.server}'
                        : 'Nenhuma fonte disponível',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),

            if (_webVideoCasterMissing)
              TextButton(
                onPressed: _opening
                    ? null
                    : () async {
                        await NativeCastBridge.openWebVideoCasterStore();
                      },
                child: const Text('Instalar Web Video Caster'),
              ),

            // Seção DLNA - Dispositivos na rede
            if (_dlnaDevices.isNotEmpty || _isScanning) ...[
              const SizedBox(height: 16),
              _buildDlnaSection(),
            ],

            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _opening
                  ? null
                  : () {
                      final openPlayer = widget.onOpenPlayer;
                      Navigator.of(context).pop();
                      openPlayer?.call();
                    },
              child: Text(
                widget.onOpenPlayer == null ? 'Voltar ao filme' : 'Abrir filme',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para encerrar, use Parar transmissão no Chromecast ou no Android.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ],
        ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected ? AppColors.primary : AppColors.textTertiary,
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
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                          const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
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
              ? 'A conexão expira em $_remainingSeconds segundos...'
              : 'Aguardando conexão com a TV... (${_remainingSeconds}s)',
          style: TextStyle(
            color: _remainingSeconds <= 10 ? Colors.orange : AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDlnaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.devices_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            const Text(
              'TVs na Rede (DLNA)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            if (_isScanning)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            else
              GestureDetector(
                onTap: _startDlnaScan,
                child: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 18),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_dlnaDevices.isEmpty && _isScanning)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Buscando Smart TVs na rede...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else
          ...List.generate(_dlnaDevices.length, (i) {
            final device = _dlnaDevices[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _opening ? null : () => _castViaDlna(device),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(device.type.icon, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              Text(
                                '${device.type.protocol} • ${device.ipAddress ?? ""}',
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_circle_outline, color: AppColors.primary, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _step(String number, String description) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. ',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}
