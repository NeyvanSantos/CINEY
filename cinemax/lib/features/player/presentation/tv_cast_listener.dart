import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/app_logger.dart';
import '../../auth/services/account_repository.dart';
import '../services/tv_cast_service.dart';

class TvCastListener extends ConsumerStatefulWidget {
  const TvCastListener({
    super.key,
    required this.isTv,
    required this.router,
    required this.child,
  });

  final bool isTv;
  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<TvCastListener> createState() => _TvCastListenerState();
}

class _TvCastListenerState extends ConsumerState<TvCastListener> {
  String? _requestedUserId;
  RealtimeChannel? _channel;

  void _scheduleReceiver(String? userId) {
    if (!widget.isTv || userId == _requestedUserId) return;
    _requestedUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _requestedUserId == userId) {
        unawaited(_connectReceiver(userId));
      }
    });
  }

  Future<void> _connectReceiver(String? userId) async {
    final previous = _channel;
    _channel = null;
    if (previous != null) {
      try {
        await previous.unsubscribe();
      } catch (error) {
        AppLogger.warn(
          'Não foi possível encerrar a sala anterior de cast (${error.runtimeType}).',
          tag: 'CAST',
        );
      }
    }
    if (!mounted || userId == null || _requestedUserId != userId) return;

    final client = ref.read(supabaseClientProvider);
    if (client == null) return;

    late final RealtimeChannel channel;
    channel = TvCastService(client).listen(
      userId: userId,
      onCommand: (command) {
        if (!mounted || _channel != channel) return;
        AppLogger.info(
          'Receiver recebeu a reprodução "${command.title}".',
          tag: 'CAST',
        );
        widget.router.go(command.playerLocation);
      },
      onStatus: (status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          AppLogger.info('Receiver CiNey TV conectado.', tag: 'CAST');
        } else if (error != null) {
          AppLogger.warn(
            'Receiver CiNey TV indisponível (${error.runtimeType}).',
            tag: 'CAST',
          );
        }
      },
    );
    _channel = channel;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accountUserProvider, (_, state) {
      _scheduleReceiver(state.valueOrNull?.id);
    });
    final account = ref.watch(accountUserProvider);
    _scheduleReceiver(account.valueOrNull?.id);
    return widget.child;
  }

  @override
  void dispose() {
    final channel = _channel;
    _channel = null;
    if (channel != null) unawaited(channel.unsubscribe());
    super.dispose();
  }
}
