import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../plugin_engine/manager/plugin_manager.dart';
import '../../../plugin_engine/runtime/tmdb_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  String _selectedLanguage = 'pt-BR';
  late Set<String> _selectedPluginIds;
  bool _isInstalling = false;

  final List<Map<String, String>> _languages = [
    {'code': 'pt-BR', 'name': 'Português (Brasil)', 'flag': '🇧🇷'},
    {'code': 'en-US', 'name': 'English (US)', 'flag': '🇺🇸'},
    {'code': 'es-ES', 'name': 'Español (Latam)', 'flag': '🇪🇸'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = ref.read(appLocaleProvider).toLanguageTag();
    // Por padrão seleciona todos os plugins para a melhor experiência unificada
    _selectedPluginIds = PluginManager.allAvailablePlugins
        .map((p) => p.manifest.id)
        .toSet();
  }

  Future<void> _selectLanguage(String code) async {
    setState(() => _selectedLanguage = code);
    ref.read(appLocaleProvider.notifier).state = localeFromLanguageCode(code);
    TmdbService.setPreferredLanguage(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isInstalling = true);

    // Simula download e ativação rápida das extensões
    await Future.delayed(const Duration(milliseconds: 1200));

    ref
        .read(pluginManagerProvider.notifier)
        .setInstalledPluginIds(_selectedPluginIds.toList());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    await prefs.setString('app_language', _selectedLanguage);

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isInstalling ? _buildInstallingView() : _buildStepContent(),
      ),
    );
  }

  Widget _buildInstallingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.download_done_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.05, 1.05),
                  duration: 800.ms,
                ),
            const SizedBox(height: 32),
            Text(
              context.tr('onboarding.installing'),
              style: AppTypography.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('onboarding.preparing'),
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    return Column(
      children: [
        // Header com Barra de Progresso
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              RichText(
                text: TextSpan(
                  text: 'CI',
                  style: AppTypography.headlineMedium.copyWith(
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
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  context
                      .tr('onboarding.step')
                      .replaceAll('{current}', '${_currentStep + 1}')
                      .replaceAll('{total}', '2'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _currentStep == 0 ? _buildLanguageStep() : _buildPluginsStep(),
        ),

        // Botões de Ação Inferiores
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Row(
            children: [
              if (_currentStep > 0) ...[
                OutlinedButton(
                  onPressed: () => setState(() => _currentStep--),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  child: Text(context.tr('onboarding.back')),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_currentStep == 0) {
                      setState(() => _currentStep = 1);
                    } else {
                      _finishOnboarding();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: Icon(
                    _currentStep == 0
                        ? Icons.arrow_forward_rounded
                        : Icons.check_circle_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    _currentStep == 0
                        ? context.tr('onboarding.continue_sources')
                        : context.tr('onboarding.install_watch'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageStep() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        const SizedBox(height: 10),
        Text(
          context.tr('onboarding.welcome'),
          style: AppTypography.displaySmall,
        ).animate().fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          context.tr('onboarding.choose_language'),
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 24),
        ..._languages.map((lang) {
          final isSelected = _selectedLanguage == lang['code'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.glassBorder,
                width: isSelected ? 1.5 : 1,
              ),
              onTap: () => _selectLanguage(lang['code']!),
              child: Row(
                children: [
                  Text(lang['flag']!, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      lang['name']!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPluginsStep() {
    final allPlugins = PluginManager.allAvailablePlugins;
    final allSelected = _selectedPluginIds.length == allPlugins.length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('onboarding.sources'),
                    style: AppTypography.headlineLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('onboarding.choose_sources'),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (allSelected) {
                    _selectedPluginIds.clear();
                  } else {
                    _selectedPluginIds = allPlugins
                        .map((p) => p.manifest.id)
                        .toSet();
                  }
                });
              },
              child: Text(
                context.tr(
                  allSelected ? 'onboarding.deselect' : 'onboarding.select_all',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...allPlugins.map((plugin) {
          final manifest = plugin.manifest;
          final isSelected = _selectedPluginIds.contains(manifest.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.glassBorder,
                width: isSelected ? 1.5 : 1,
              ),
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedPluginIds.remove(manifest.id);
                  } else {
                    _selectedPluginIds.add(manifest.id);
                  }
                });
              },
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primarySurface
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.glassBorder,
                      ),
                    ),
                    child: Icon(
                      Iconsax.video_play,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textTertiary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              manifest.name,
                              style: AppTypography.labelLarge,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              manifest.langFlag,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          manifest.description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedPluginIds.add(manifest.id);
                        } else {
                          _selectedPluginIds.remove(manifest.id);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
