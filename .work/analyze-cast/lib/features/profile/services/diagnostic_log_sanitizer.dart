import '../../../core/services/app_logger.dart';

class DiagnosticLogSanitizer {
  const DiagnosticLogSanitizer._();

  static List<Map<String, String>> sanitize(Iterable<LogEntry> entries) {
    return entries
        .toList(growable: false)
        .reversed
        .take(500)
        .toList(growable: false)
        .reversed
        .map((entry) {
          final sanitizedTag = sanitizeText(entry.tag);
          final sanitizedMessage = sanitizeText(entry.message);
          return {
            'timestamp': entry.timestamp.toUtc().toIso8601String(),
            'level': entry.levelLabel,
            'tag': sanitizedTag.substring(
              0,
              sanitizedTag.length > 200 ? 200 : sanitizedTag.length,
            ),
            'message': sanitizedMessage.substring(
              0,
              sanitizedMessage.length > 4000 ? 4000 : sanitizedMessage.length,
            ),
          };
        })
        .toList(growable: false);
  }

  static String sanitizeText(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'\bBearer\s+[^\s,;]+', caseSensitive: false),
          (_) => 'Bearer [REDACTED]',
        )
        .replaceAllMapped(
          RegExp(
            r'''\b(password|passwd|access[_-]?token|refresh[_-]?token|authorization|api[_-]?key|secret)\b(\s*[:=]\s*)("[^"]*"|'[^']*'|[^\s,;]+)''',
            caseSensitive: false,
          ),
          (match) => '${match[1]}${match[2]}[REDACTED]',
        )
        .replaceAllMapped(
          RegExp(
            r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
            caseSensitive: false,
          ),
          (_) => '[EMAIL]',
        )
        .replaceAllMapped(
          RegExp(r'https?://[^\s?]+\?[^\s]+', caseSensitive: false),
          (match) => '${match[0]!.split('?').first}?[REDACTED]',
        );
  }
}
