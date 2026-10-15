import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// API interna: nenhuma URL ou credencial é enviada para outro aplicativo.
class CastLiteEngine {
  static const methods = MethodChannel('com.ciney/castlite');
  static const _events = EventChannel('com.ciney/castlite/events');
  static final Stream<Map<String, dynamic>> states = _events
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map));

  static bool get supportsPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> isAvailable() async =>
      supportsPlatform &&
      await methods.invokeMethod<bool>('isAvailable') == true;

  static Future<void> open(Map<String, Object?> request) async {
    if (!supportsPlatform) {
      throw UnsupportedError('Transmissão disponível no Android.');
    }
    await methods.invokeMethod<void>('open', request);
  }

  static Future<Map<String, dynamic>> getState() async {
    if (!supportsPlatform) return const {'state': 'unavailable'};
    final state = await methods.invokeMapMethod<String, dynamic>('getState');
    return state ?? const {'state': 'idle'};
  }

  static Future<void> command(String action, {int? positionMs}) async {
    const actions = {'play', 'pause', 'stop', 'seek', 'showControls'};
    if (!actions.contains(action) ||
        (action == 'seek' && (positionMs == null || positionMs < 0))) {
      throw ArgumentError('Comando de transmissão inválido.');
    }
    if (!supportsPlatform) return;
    await methods.invokeMethod<void>(action, {'positionMs': ?positionMs});
  }
}
