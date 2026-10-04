import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LogLevel { debug, info, warning, error, success }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  String get levelLabel {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.success:
        return 'OK';
    }
  }

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  String toString() => '[$formattedTime] [$levelLabel] [$tag] $message';
}

/// Serviço global de logging em tempo real do Cinemax.
/// Registra eventos de busca, streams, plugins, erros e navegação.
class AppLogger {
  AppLogger._();

  static final _controller = StreamController<LogEntry>.broadcast();
  static final _changes = StreamController<void>.broadcast(sync: true);
  static final _entries = <LogEntry>[];
  static const int _maxEntries = 500;

  static Stream<LogEntry> get stream => _controller.stream;
  static List<LogEntry> get entries => List.unmodifiable(_entries);

  static void _add(LogLevel level, String tag, String message) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    _controller.add(entry);
    _changes.add(null);
  }

  static void debug(String message, {String tag = 'APP'}) =>
      _add(LogLevel.debug, tag, message);

  static void info(String message, {String tag = 'APP'}) =>
      _add(LogLevel.info, tag, message);

  static void warn(String message, {String tag = 'APP'}) =>
      _add(LogLevel.warning, tag, message);

  static void error(
    String message, {
    String tag = 'APP',
    StackTrace? stackTrace,
  }) => _add(
    LogLevel.error,
    tag,
    stackTrace == null ? message : '$message\n$stackTrace',
  );

  static void success(String message, {String tag = 'APP'}) =>
      _add(LogLevel.success, tag, message);

  static void clear() {
    _entries.clear();
    _changes.add(null);
  }

  static String exportAll() => _entries.join('\n');
}

/// Provider Riverpod: mantém a lista de logs em tempo real via Stream.
final appLogProvider = StreamProvider.autoDispose<List<LogEntry>>((ref) {
  late StreamController<List<LogEntry>> controller;
  StreamSubscription<void>? subscription;
  controller = StreamController<List<LogEntry>>(
    onListen: () {
      subscription = AppLogger._changes.stream.listen((_) {
        controller.add(AppLogger.entries);
      });
      controller.add(AppLogger.entries);
    },
    onCancel: () => subscription?.cancel(),
  );
  ref.onDispose(() {
    subscription?.cancel();
    controller.close();
  });
  return controller.stream;
});
