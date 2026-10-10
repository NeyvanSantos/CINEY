import 'dart:convert';
import 'dart:io' as io;

import 'package:cinemax/core/services/app_logger.dart';
import 'package:cinemax/features/profile/services/diagnostic_report_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '10000000-0000-0000-0000-000000000001';

void main() {
  late io.HttpServer server;
  late SupabaseClient client;
  Map<String, dynamic>? sentReport;
  String? functionAuthorization;

  Map<String, dynamic> session() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    return {
      'access_token':
          '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': _userId, 'exp': now + 3600, 'iat': now, 'role': 'authenticated'})}.signature',
      'refresh_token': 'local-test-refresh-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': _userId,
        'email': 'person@example.com',
        'aud': 'authenticated',
        'role': 'authenticated',
        'app_metadata': {'provider': 'email'},
        'user_metadata': {},
        'created_at': '2026-01-01T00:00:00Z',
      },
    };
  }

  setUp(() async {
    sentReport = null;
    functionAuthorization = null;
    server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      request.response.headers.contentType = io.ContentType.json;
      Object response = {};
      if (request.uri.path == '/auth/v1/token') {
        response = session();
      } else if (request.uri.path == '/functions/v1/submit-diagnostic-report') {
        functionAuthorization = request.headers.value('authorization');
        sentReport = jsonDecode(raw) as Map<String, dynamic>;
        response = {'report_id': 'report-123'};
        request.response.statusCode = 201;
      }
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'local-test-public-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('envia logs sanitizados com a sessão e recebe protocolo', () async {
    await client.auth.signInWithPassword(
      email: 'person@example.com',
      password: 'password-123',
    );
    final service = DiagnosticReportService(client);
    final reportId = await service.submit(
      entries: [
        LogEntry(
          timestamp: DateTime.utc(2026, 10, 10, 12),
          level: LogLevel.error,
          tag: 'SEARCH',
          message:
              'Falha para ana@example.com; access_token=secret-value; '
              'https://api.example.test/search?q=private',
        ),
      ],
      description: 'Busca falha para dev@example.com',
      appVersion: '1.0.28+25',
      platform: 'android',
    );

    expect(reportId, 'report-123');
    expect(functionAuthorization, startsWith('Bearer '));
    expect(sentReport?['app_version'], '1.0.28+25');
    expect(sentReport?['platform'], 'android');
    expect(sentReport?['description'], 'Busca falha para [EMAIL]');
    final log = (sentReport?['logs'] as List).single as Map;
    expect(log['level'], 'ERROR');
    expect(log['message'], contains('[EMAIL]'));
    expect(log['message'], contains('access_token=[REDACTED]'));
    expect(
      log['message'],
      contains('https://api.example.test/search?[REDACTED]'),
    );
    expect(log['message'], isNot(contains('secret-value')));
    expect(log['message'], isNot(contains('q=private')));
  });

  test('recusa envio sem uma sessão autenticada', () async {
    await expectLater(
      DiagnosticReportService(client).submit(
        entries: [
          LogEntry(
            timestamp: DateTime.now(),
            level: LogLevel.error,
            tag: 'TEST',
            message: 'Falha',
          ),
        ],
        description: '',
        appVersion: '1.0.0',
        platform: 'android',
      ),
      throwsA(isA<StateError>()),
    );
    expect(sentReport, isNull);
  });
}
