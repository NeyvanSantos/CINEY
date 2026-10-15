import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'mobile_push_service.dart';
import 'notification_policy.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final push = MobilePushService.instance;
  Map<String, bool>? _preferences;
  bool _busy = false;
  bool _allowed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await push.loadPreferences();
      final allowed = await push.permissionGranted();
      if (mounted) {
        setState(() {
          _preferences = prefs;
          _allowed = allowed;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível carregar. Confira a conexão e tente novamente.',
        );
      }
    }
  }

  Future<void> _perform(
    Future<void> Function() action, {
    String? success,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _load();
      if (mounted && success != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível concluir. Confira a conexão e a permissão. Para um novo teste, aguarde um minuto.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notificações')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Escolha quais novidades você quer receber. O catálogo tem um resumo diário; os favoritos recebem avisos de episódios anunciados.',
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Tentar novamente'),
          ),
        ],
        if (_preferences == null && _error == null)
          const Center(child: CircularProgressIndicator()),
        if (_preferences != null) ...[
          for (final entry in notificationPreferenceLabels.entries)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              value: _preferences![entry.key]!,
              onChanged:
                  _busy ||
                      (entry.key != 'enabled' && !_preferences!['enabled']!)
                  ? null
                  : (value) =>
                        _perform(() => push.savePreference(entry.key, value)),
            ),
          if (!_allowed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_off_outlined),
              title: const Text(
                'Permita as notificações nas configurações do aparelho',
              ),
              trailing: TextButton(
                onPressed: () async {
                  await openAppSettings();
                },
                child: const Text('Abrir'),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy || !_preferences!['enabled']!
                ? null
                : () => _perform(
                    push.sendTest,
                    success:
                        'Aviso de teste enviado somente para este aparelho.',
                  ),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Enviar aviso de teste'),
          ),
        ],
      ],
    ),
  );
}
