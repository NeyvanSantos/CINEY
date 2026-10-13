import 'package:flutter/material.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: GlassCard(
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Excluir sua conta?', style: AppTypography.headlineMedium),
              const SizedBox(height: 16),
              const Text(
                'Seu perfil e seus favoritos serão apagados permanentemente. Digite sua senha para confirmar.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Senha atual'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Informe sua senha.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(context, _password.text);
                  }
                },
                child: const Text('Excluir definitivamente'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
