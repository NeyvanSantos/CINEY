import 'package:cinemax/core/services/app_logger.dart';
import 'package:cinemax/features/profile/services/diagnostic_log_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserva metadados e mascara credenciais, e-mail e query da URL', () {
    final entries = [
      LogEntry(
        timestamp: DateTime.utc(2026, 10, 10, 12),
        level: LogLevel.error,
        tag: 'SEARCH',
        message:
            'Falha para ana@example.com com access_token=abc123; '
            'Bearer eyJhbGciOi.test e https://api.example.test/search?q=segredo',
      ),
    ];

    final sanitized = DiagnosticLogSanitizer.sanitize(entries).single;

    expect(sanitized['level'], 'ERROR');
    expect(sanitized['tag'], 'SEARCH');
    expect(sanitized['timestamp'], '2026-10-10T12:00:00.000Z');
    expect(sanitized['message'], contains('[EMAIL]'));
    expect(sanitized['message'], contains('access_token=[REDACTED]'));
    expect(sanitized['message'], contains('Bearer [REDACTED]'));
    expect(
      sanitized['message'],
      contains('https://api.example.test/search?[REDACTED]'),
    );
    expect(sanitized['message'], isNot(contains('abc123')));
    expect(sanitized['message'], isNot(contains('ana@example.com')));
    expect(sanitized['message'], isNot(contains('q=segredo')));
  });
}
