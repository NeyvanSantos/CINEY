import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/account_messages.dart';
import '../services/account_repository.dart';

class TvPairingScannerScreen extends ConsumerStatefulWidget {
  const TvPairingScannerScreen({super.key});

  @override
  ConsumerState<TvPairingScannerScreen> createState() =>
      _TvPairingScannerScreenState();
}

class _TvPairingScannerScreenState
    extends ConsumerState<TvPairingScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _approve(String payload) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await _controller.stop();
    try {
      await ref.read(accountRepositoryProvider).approveTvPairing(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('TV autorizada.')));
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = accountErrorMessage(error);
      });
      await _controller.start();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final payload = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (payload != null) unawaited(_approve(payload));
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountUserProvider);
    final user = account.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text('Ler QR da TV', style: AppTypography.headlineMedium),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: account.isLoading
                  ? const CircularProgressIndicator()
                  : user == null
                  ? GlassCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            color: AppColors.primary,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Entre no Android para autorizar a TV.',
                            style: AppTypography.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => context.go('/auth'),
                            child: const Text('Entrar na conta'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                MobileScanner(
                                  controller: _controller,
                                  onDetect: _onDetect,
                                ),
                                IgnorePointer(
                                  child: Container(
                                    width: 250,
                                    height: 250,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 3,
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                  ),
                                ),
                                if (_busy)
                                  const ColoredBox(
                                    color: Color(0x990A0A1A),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Escaneando como ${user.email}',
                          style: AppTypography.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
