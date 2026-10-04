import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/app_updater.dart';
import '../../../core/widgets/update_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusText = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Animação mínima do splash
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Verifica atualizações em paralelo
    setState(() => _statusText = 'Verificando atualizações...');

    try {
      final updateInfo = await AppUpdater.checkForUpdates();

      if (!mounted) return;

      if (updateInfo != null && updateInfo.hasUpdate) {
        AppLogger.info(
          'Atualização encontrada: v${updateInfo.latestVersion}',
          tag: 'UPDATER',
        );
        // Mostra o dialog e espera o usuário decidir
        await UpdateDialog.show(context, updateInfo);
      }
    } catch (e) {
      AppLogger.warn('Falha ao verificar atualizações: $e', tag: 'UPDATER');
    }

    if (!mounted) return;

    // Segue para a rota normal
    setState(() => _statusText = 'Preparando...');
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;
    _navigateToInitialRoute();
  }

  Future<void> _navigateToInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final isCompleted = prefs.getBool('onboarding_completed') ?? false;

    if (mounted) {
      if (isCompleted) {
        context.go('/home');
      } else {
        context.go('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Icon animado com gradiente e borda
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 60,
              ),
            )
                .animate()
                .scale(duration: 700.ms, curve: Curves.easeOutBack)
                .then()
                .shimmer(duration: 1200.ms),

            const SizedBox(height: 24),

            // Título do App
            RichText(
              text: TextSpan(
                text: 'CI',
                style: AppTypography.displayMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
                children: const [
                  TextSpan(
                    text: 'NEY',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 800.ms, delay: 300.ms)
                .slideY(begin: 0.3, end: 0),

            const SizedBox(height: 8),

            Text(
              'Filmes, Séries & Animes Sem Limites',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ).animate().fadeIn(duration: 800.ms, delay: 500.ms),

            const SizedBox(height: 48),

            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 800.ms),

            const SizedBox(height: 12),

            // Status text
            Text(
              _statusText,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                letterSpacing: 0.3,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 1000.ms),
          ],
        ),
      ),
    );
  }
}

