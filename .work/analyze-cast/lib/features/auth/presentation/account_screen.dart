import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/account_messages.dart';
import '../services/account_repository.dart';
import 'delete_account_dialog.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _name;
  String? _error;

  Future<void> _run(
    Future<void> Function() action, {
    bool leave = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(profileNameProvider);
      if (leave) {
        context.go('/profile');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nome atualizado.')));
      }
    } catch (error) {
      final message = accountErrorMessage(error);
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const DeleteAccountDialog(),
    );
    if (password != null && mounted) {
      await _run(
        () => ref.read(accountRepositoryProvider).deleteAccount(password),
        leave: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(accountUserProvider).valueOrNull;
    final name = ref.watch(profileNameProvider);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Minha conta', style: AppTypography.headlineMedium),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (user == null && !_busy)
                  GlassCard(
                    child: Column(
                      children: [
                        const Text('Entre para gerenciar sua conta.'),
                        TextButton(
                          onPressed: () => context.push('/auth'),
                          child: const Text('Entrar'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          user?.email ?? '',
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        name.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) => Column(
                            children: [
                              const Text(
                                'Não foi possível carregar seu perfil.',
                              ),
                              TextButton(
                                onPressed: () =>
                                    ref.invalidate(profileNameProvider),
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                          data: (value) => Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  initialValue: value,
                                  enabled: !_busy,
                                  maxLength: 60,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome',
                                  ),
                                  validator: validateDisplayName,
                                  onSaved: (value) => _name = value?.trim(),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () {
                                          if (_form.currentState!.validate()) {
                                            _form.currentState!.save();
                                            _run(
                                              () => ref
                                                  .read(
                                                    accountRepositoryProvider,
                                                  )
                                                  .updateDisplayName(_name!),
                                            );
                                          }
                                        },
                                  child: const Text('Salvar nome'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _error!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            ref.read(accountRepositoryProvider).signOut,
                            leave: true,
                          ),
                    child: const Text('Sair desta conta'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : _confirmDelete,
                    child: const Text(
                      'Excluir conta',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
