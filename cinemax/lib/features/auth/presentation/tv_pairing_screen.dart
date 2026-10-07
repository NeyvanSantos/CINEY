import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../models/tv_pairing_request.dart';
import '../services/account_messages.dart';
import '../services/account_repository.dart';

class TvPairingScreen extends ConsumerStatefulWidget {
  const TvPairingScreen({super.key});

  @override
  ConsumerState<TvPairingScreen> createState() => _TvPairingScreenState();
}

class _TvPairingScreenState extends ConsumerState<TvPairingScreen> {
  TvPairingRequest? _request;
  Timer? _pollTimer;
  bool _starting = false;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_createPairing());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createPairing() async {
    _pollTimer?.cancel();
    setState(() {
      _starting = true;
      _request = null;
      _error = null;
    });
    try {
      final request = await ref
          .read(accountRepositoryProvider)
          .createTvPairing();
      if (!mounted) return;
      setState(() {
        _request = request;
        _starting = false;
      });
      _pollTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_checkPairing(request)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = accountErrorMessage(error);
      });
    }
  }

  Future<void> _checkPairing(TvPairingRequest request) async {
    if (_checking || !mounted) return;
    if (DateTime.now().isAfter(request.expiresAt)) {
      _pollTimer?.cancel();
      setState(() => _error = 'Este QR expirou. Gere um novo para continuar.');
      return;
    }
    _checking = true;
    try {
      final connected = await ref
          .read(accountRepositoryProvider)
          .checkTvPairing(request);
      if (connected && mounted) {
        _pollTimer?.cancel();
        context.go('/profile');
      } else if (mounted) {
        setState(() {});
      }
    } catch (error) {
      _pollTimer?.cancel();
      if (mounted) setState(() => _error = accountErrorMessage(error));
    } finally {
      _checking = false;
    }
  }

  String _remainingTime(DateTime expiresAt) {
    final seconds = expiresAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 300);
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return Scaffold(
      appBar: AppBar(
        title: Text('Conectar esta TV', style: AppTypography.headlineMedium),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      color: AppColors.primary,
                      size: 42,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Entre com sua conta do Android',
                      style: AppTypography.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No Android, abra Perfil e toque em “Conectar TV”. Escaneie este código para autorizar esta tela.',
                      style: AppTypography.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_starting)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      )
                    else if (_error != null)
                      Column(
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _createPairing,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Gerar novo QR'),
                          ),
                        ],
                      )
                    else if (request != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: request.qrPayload,
                          version: QrVersions.auto,
                          size: 260,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppColors.primary,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppColors.background,
                          ),
                          semanticsLabel: 'QR para conectar a conta na TV',
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: AppColors.primaryLight,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Código temporário · ${_remainingTime(request.expiresAt)}',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        'Aguardando autorização pelo Android',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
