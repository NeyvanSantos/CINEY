import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/app_logger.dart';
import 'diagnostic_log_sanitizer.dart';

class DiagnosticReportService {
  DiagnosticReportService(this.client);

  static const int maxPayloadBytes = 220 * 1024;
  final SupabaseClient? client;

  Future<String> submit({
    required List<LogEntry> entries,
    required String description,
    required String appVersion,
    required String platform,
  }) async {
    final supabase = client;
    if (supabase == null || supabase.auth.currentUser == null) {
      throw StateError('Entre na sua conta para enviar um relatório.');
    }
    if (entries.isEmpty) {
      throw StateError('Não há logs para enviar.');
    }

    final logs = DiagnosticLogSanitizer.sanitize(entries);
    final payload = <String, dynamic>{
      'description': DiagnosticLogSanitizer.sanitizeText(description).trim(),
      'app_version': appVersion.trim(),
      'platform': platform.trim(),
      'logs': logs,
    };
    while (utf8.encode(jsonEncode(payload)).length > maxPayloadBytes &&
        (payload['logs'] as List).length > 1) {
      (payload['logs'] as List).removeAt(0);
    }
    if (utf8.encode(jsonEncode(payload)).length > maxPayloadBytes) {
      throw StateError('Os logs excedem o limite permitido para envio.');
    }

    final response = await supabase.functions.invoke(
      'submit-diagnostic-report',
      body: payload,
    );
    final responseData = response.data;
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Não foi possível enviar o relatório.');
    }
    if (responseData is! Map || responseData['report_id'] is! String) {
      throw StateError('O servidor não confirmou o recebimento do relatório.');
    }
    return responseData['report_id'] as String;
  }
}
