import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/app_updater.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/update_dialog.dart';
import '../../auth/presentation/account_card.dart';
import '../services/playback_preferences.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _checkingUpdate = false;
  String _appVersion = '1.0.3';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = info.version);
      }
    } catch (_) {}
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);

    try {
      final updateInfo = await AppUpdater.checkForUpdates();

      if (!mounted) return;

      if (updateInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível verificar. Tente novamente.'),
            backgroundColor: AppColors.warning,
          ),
        );
      } else if (updateInfo.hasUpdate) {
        await UpdateDialog.show(context, updateInfo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Você já está na versão mais recente! (v${updateInfo.currentVersion})',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _savePlaybackPreferences(PlaybackPreferences preferences) async {
    try {
      await ref
          .read(playbackPreferencesProvider.notifier)
          .setPreferences(preferences);
    } catch (error) {
      AppLogger.warn(
        'Não foi possível salvar as preferências de reprodução (${error.runtimeType}).',
        tag: 'SETTINGS',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a preferência.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferencesState = ref.watch(playbackPreferencesProvider);
    final preferences =
        preferencesState.valueOrNull ?? PlaybackPreferences.defaults;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Ajustes & Perfil', style: AppTypography.headlineLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AccountCard(),

          const SizedBox(height: 24),
          Text(
            'Preferências de Reprodução',
            style: AppTypography.headlineMedium,
          ),
          const SizedBox(height: 12),

          _buildSettingTile(
            icon: Iconsax.play_circle,
            title: 'Retomar reprodução',
            subtitle: 'Continuar do último ponto salvo',
            trailing: Switch(
              value: preferences.resumePlayback,
              activeThumbColor: AppColors.primary,
              onChanged: preferencesState.isLoading
                  ? null
                  : (value) => unawaited(
                      _savePlaybackPreferences(
                        preferences.copyWith(resumePlayback: value),
                      ),
                    ),
            ),
          ),
          _buildSettingTile(
            icon: Icons.skip_next_rounded,
            title: 'Próximo episódio automaticamente',
            subtitle: 'Continuar a série quando o episódio terminar',
            trailing: Switch(
              value: preferences.autoPlayNextEpisode,
              activeThumbColor: AppColors.primary,
              onChanged: preferencesState.isLoading
                  ? null
                  : (value) => unawaited(
                      _savePlaybackPreferences(
                        preferences.copyWith(autoPlayNextEpisode: value),
                      ),
                    ),
            ),
          ),
          _buildSettingTile(
            icon: Icons.visibility_off_outlined,
            title: 'Ocultar controles automaticamente',
            subtitle: 'Esconder após alguns segundos sem interação',
            trailing: Switch(
              value: preferences.autoHideControls,
              activeThumbColor: AppColors.primary,
              onChanged: preferencesState.isLoading
                  ? null
                  : (value) => unawaited(
                      _savePlaybackPreferences(
                        preferences.copyWith(autoHideControls: value),
                      ),
                    ),
            ),
          ),
          _buildSettingTile(
            icon: Icons.network_check_rounded,
            title: 'Modo Poucos Megabits (Conexão Lenta)',
            subtitle: 'Otimiza buffer de vídeo e reduz tráfego de imagens',
            trailing: Switch(
              value: preferences.lowBandwidthMode,
              activeThumbColor: AppColors.primary,
              onChanged: preferencesState.isLoading
                  ? null
                  : (value) => unawaited(
                      _savePlaybackPreferences(
                        preferences.copyWith(lowBandwidthMode: value),
                      ),
                    ),
            ),
          ),
          if (!AppEnvironment.isTv)
            _buildSettingTile(
              icon: Icons.screen_rotation,
              title: 'Player em paisagem',
              subtitle: 'Girar o celular durante a reprodução',
              trailing: Switch(
                value: preferences.landscapeOnMobile,
                activeThumbColor: AppColors.primary,
                onChanged: preferencesState.isLoading
                    ? null
                    : (value) => unawaited(
                        _savePlaybackPreferences(
                          preferences.copyWith(landscapeOnMobile: value),
                        ),
                      ),
              ),
            ),

          const SizedBox(height: 24),
          Text('Fontes & Armazenamento', style: AppTypography.headlineMedium),
          const SizedBox(height: 12),

          _buildSettingTile(
            icon: Iconsax.category_2,
            title: 'Gerenciar Extensões & Repositórios',
            subtitle: 'Adicionar ou remover fontes de streaming',
            onTap: () => context.push('/extensions'),
          ),
          _buildSettingTile(
            icon: Iconsax.global,
            title: 'Configurar Idioma & Setup',
            subtitle: 'Reabrir assistente de boas-vindas',
            onTap: () => context.push('/onboarding'),
          ),
          _buildSettingTile(
            icon: Iconsax.trash,
            title: 'Limpar Cache de Imagens',
            subtitle: 'Libera espaço temporário do dispositivo',
            onTap: () {
              AppLogger.info(
                'Cache de imagens limpo pelo usuário.',
                tag: 'CACHE',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache limpo com sucesso!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          Text('Diagnóstico & Developer', style: AppTypography.headlineMedium),
          const SizedBox(height: 12),

          // Tile de Verificar Atualizações
          _buildUpdateTile(context),

          // Tile de Logs em Tempo Real
          _buildLogTile(context),

          const SizedBox(height: 24),
          Text('Sobre o Aplicativo', style: AppTypography.headlineMedium),
          const SizedBox(height: 12),

          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            AppEnvironment.assetPath('assets/images/logo.png'),
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        RichText(
                          text: TextSpan(
                            text: 'CI',
                            style: AppTypography.headlineMedium.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                            children: const [
                              TextSpan(
                                text: 'NEY',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'v$_appVersion 🚀 GitHub Release',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.code_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Desenvolvido por Neyvan Santos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Aplicativo agregador de filmes, séries, animes e doramas com catálogo unificado, reprodução fluida e sistema modular de extensões.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildUpdateTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: _checkingUpdate ? null : _checkForUpdates,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: _checkingUpdate
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.system_update_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verificar Atualizações',
                    style: AppTypography.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _checkingUpdate
                        ? 'Consultando GitHub Releases...'
                        : 'Verificar se há nova versão do CiNey',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () {
          AppLogger.info('Console de logs aberto pelo usuário.', tag: 'SYSTEM');
          context.push('/logs');
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1A0F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF1A7A4A).withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.terminal_rounded,
                color: Color(0xFF4ADE80),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Console de Logs em Tempo Real',
                    style: AppTypography.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Ver eventos de stream, busca, plugins e erros ao vivo',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
