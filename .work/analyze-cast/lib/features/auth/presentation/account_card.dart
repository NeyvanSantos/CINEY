import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/account_repository.dart';

class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountUserProvider);
    final user = account.valueOrNull;
    final name = ref.watch(profileNameProvider);
    final configured = ref.watch(accountRepositoryProvider).isConfigured;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                child: Icon(Icons.person_outline, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user == null
                          ? 'Visitante'
                          : name.isLoading
                          ? 'Sua conta'
                          : name.valueOrNull ?? 'Sua conta',
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'Entre para sincronizar seus favoritos.',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (account.isLoading)
            const LinearProgressIndicator()
          else if (account.hasError) ...[
            const Text('Não foi possível carregar sua sessão.'),
            TextButton(
              onPressed: () => ref.invalidate(accountUserProvider),
              child: const Text('Tentar novamente'),
            ),
          ] else if (user == null) ...[
            if (AppEnvironment.isTv && configured) ...[
              OutlinedButton.icon(
                onPressed: () => context.push('/tv-pair'),
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Conectar com Android'),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: () => context.push('/auth'),
              child: Text(
                configured ? 'Entrar ou criar conta' : 'Sobre as contas',
              ),
            ),
          ] else
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => context.push('/favorites'),
                  icon: const Icon(Icons.favorite_outline),
                  label: const Text('Meus favoritos'),
                ),
                if (!AppEnvironment.isTv)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/tv-pair-scan'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Conectar TV'),
                  ),
                OutlinedButton(
                  onPressed: () => context.push('/account'),
                  child: const Text('Gerenciar conta'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
