import 'package:cinemax/core/services/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(AppLogger.clear);
  tearDown(AppLogger.clear);

  test('mantém os últimos 500 registros e exporta os detalhes do erro', () {
    for (var i = 0; i < 501; i++) {
      AppLogger.info('Evento $i');
    }
    expect(AppLogger.entries, hasLength(500));
    expect(AppLogger.entries.first.message, 'Evento 1');
    final snapshot = AppLogger.entries;
    AppLogger.error(
      'Falha de reprodução',
      tag: 'PLAYER',
      stackTrace: StackTrace.fromString('player.dart:42'),
    );
    expect(snapshot.last.message, 'Evento 500');
    expect(
      AppLogger.exportAll(),
      contains('[ERROR] [PLAYER] Falha de reprodução\nplayer.dart:42'),
    );
    expect(() => snapshot.clear(), throwsUnsupportedError);
  });

  test(
    'provider entrega histórico, novos eventos e limpeza sem novo log',
    () async {
      AppLogger.info('Antes de abrir');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final updates = <List<LogEntry>>[];
      final subscription = container.listen(appLogProvider, (_, next) {
        next.whenData(updates.add);
      }, fireImmediately: true);
      addTearDown(subscription.close);
      expect(
        (await container.read(appLogProvider.future)).single.message,
        'Antes de abrir',
      );
      AppLogger.warn('Servidor indisponível', tag: 'PLAYER');
      AppLogger.clear();
      await Future<void>.delayed(Duration.zero);
      expect(updates.any((entries) => entries.length == 2), isTrue);
      expect(updates.last, isEmpty);
      expect(AppLogger.exportAll(), isEmpty);
    },
  );
}
