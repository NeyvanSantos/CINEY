import 'dart:convert';
import 'dart:io' as io;
import 'package:cinemax/features/auth/services/account_repository.dart';
import 'package:cinemax/features/favorites/services/favorites_repository.dart';
import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '10000000-0000-0000-0000-000000000001';

void main() {
  late io.HttpServer server;
  late SupabaseClient client;
  late SupabaseAccountRepository accounts;
  final requests =
      <
        ({String path, String method, Map<String, String> query, dynamic body})
      >[];
  var rejectPassword = false;
  var rejectLogout = false;
  var pairingReady = false;

  Map<String, dynamic> user() => {
    'id': _userId,
    'email': 'person@example.com',
    'aud': 'authenticated',
    'role': 'authenticated',
    'app_metadata': {'provider': 'email'},
    'user_metadata': {},
    'created_at': '2026-01-01T00:00:00Z',
  };

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
      'user': user(),
    };
  }

  setUp(() async {
    requests.clear();
    rejectPassword = false;
    rejectLogout = false;
    pairingReady = false;
    server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      requests.add((
        path: request.uri.path,
        method: request.method,
        query: request.uri.queryParameters,
        body: raw.isEmpty ? null : jsonDecode(raw),
      ));
      request.response.headers.contentType = io.ContentType.json;
      Object? response;
      switch (request.uri.path) {
        case '/auth/v1/token':
          if (rejectPassword) {
            request.response.statusCode = 400;
            response = {
              'code': 'invalid_credentials',
              'msg': 'Invalid credentials',
            };
          } else {
            response = session();
          }
        case '/auth/v1/logout':
          if (rejectLogout) {
            request.response.statusCode = 400;
            response = {'msg': 'Remote logout unavailable'};
          } else {
            response = {};
          }
        case '/auth/v1/signup':
          response = user();
        case '/auth/v1/verify':
          response = session();
        case '/auth/v1/user':
          response = user();
        case '/rest/v1/profiles':
          response = {'display_name': 'Pessoa'};
        case '/functions/v1/tv-pairing':
          final action = (jsonDecode(raw) as Map<String, dynamic>)['action'];
          response = switch (action) {
            'start' => {
              'id': 'pairing-id',
              'secret': 'pairing-secret',
              'expiresAt': '2026-10-07T12:05:00.000Z',
            },
            'approve' => {'status': 'approved'},
            'poll' =>
              pairingReady
                  ? {
                      'status': 'ready',
                      'email': 'person@example.com',
                      'tokenHash': 'one-time-token-hash',
                    }
                  : {'status': 'pending'},
            'complete' => {'status': 'consumed'},
            _ => {'error': 'Unknown action'},
          };
        default:
          response = {};
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
    accounts = SupabaseAccountRepository(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test(
    'SDK usa nome e e-mail no cadastro, sem pressupor sessão antes da confirmação',
    () async {
      expect(
        await accounts.signUp(
          ' Pessoa ',
          ' person@example.com ',
          'password-123',
        ),
        isFalse,
      );
      expect(accounts.currentUser, isNull);
      expect(requests.single.body['email'], 'person@example.com');
      expect(requests.single.body['data'], {'display_name': 'Pessoa'});
      await accounts.confirmEmail(' person@example.com ', ' 123456 ');
      expect(requests.last.body['type'], 'signup');
      expect(requests.last.body['token'], '123456');
      expect(accounts.currentUser?.id, _userId);
    },
  );

  test('recuperação usa OTP recovery antes de atualizar a senha', () async {
    await accounts.requestPasswordReset(' person@example.com ');
    expect(requests.last.path, '/auth/v1/recover');
    expect(requests.last.body['email'], 'person@example.com');
    await accounts.verifyRecovery('person@example.com', '123456');
    expect(requests.last.body['type'], 'recovery');
    await accounts.updatePassword('new-password-123');
    expect(requests.last.path, '/auth/v1/user');
    expect(requests.last.body['password'], 'new-password-123');
  });

  test(
    'pareamento cria QR temporário e aprova somente payload CiNey',
    () async {
      final pairing = await accounts.createTvPairing();
      expect(pairing.id, 'pairing-id');
      expect(Uri.parse(pairing.qrPayload).queryParameters, {
        'id': 'pairing-id',
        'secret': 'pairing-secret',
      });

      await accounts.approveTvPairing(pairing.qrPayload);
      expect(requests.last.path, '/functions/v1/tv-pairing');
      expect(requests.last.body['action'], 'approve');
      expect(requests.last.body['id'], 'pairing-id');

      final requestCount = requests.length;
      await expectLater(
        accounts.approveTvPairing('https://example.com/not-a-pairing'),
        throwsFormatException,
      );
      expect(requests, hasLength(requestCount));
    },
  );

  test('TV aguarda aprovação e troca QR por sessão magic link', () async {
    final pairing = await accounts.createTvPairing();
    expect(await accounts.checkTvPairing(pairing), isFalse);

    pairingReady = true;
    expect(await accounts.checkTvPairing(pairing), isTrue);
    final verification = requests.firstWhere(
      (request) => request.path == '/auth/v1/verify',
    );
    expect(verification.body['type'], 'magiclink');
    expect(verification.body['token_hash'], 'one-time-token-hash');
    expect(verification.body.containsKey('token'), isFalse);
    expect(requests.last.body['action'], 'complete');
    expect(accounts.currentUser?.id, _userId);
  });

  test(
    'favoritos usam identidade completa e recusam gravação após troca de conta',
    () async {
      await accounts.signIn('person@example.com', 'password-123');
      final favorites = SupabaseFavoritesRepository(client);
      const item = ContentItem(
        id: 'same/id',
        pluginId: 'source-a',
        type: ContentType.movie,
        title: 'Filme',
        posterUrl: '',
      );
      await favorites.setFavorite(_userId, item, saved: true);
      expect(requests.last.body, {
        'user_id': _userId,
        'content_id': 'same/id',
        'plugin_id': 'source-a',
        'content_type': 'movie',
        'title': 'Filme',
        'poster_url': '',
      });
      expect(
        requests.last.query['on_conflict'],
        'user_id,content_id,plugin_id,content_type',
      );
      await favorites.setFavorite(_userId, item, saved: false);
      expect(requests.last.method, 'DELETE');
      expect(requests.last.query['user_id'], 'eq.$_userId');
      expect(requests.last.query['content_id'], 'eq.same/id');
      expect(requests.last.query['plugin_id'], 'eq.source-a');
      expect(requests.last.query['content_type'], 'eq.movie');
      final count = requests.length;
      await expectLater(
        favorites.setFavorite('other-user', item, saved: true),
        throwsStateError,
      );
      expect(requests.length, count);
    },
  );

  test('senha incorreta impede a chamada de exclusão', () async {
    await accounts.signIn('person@example.com', 'password-123');
    rejectPassword = true;
    await expectLater(
      accounts.deleteAccount('wrong-password'),
      throwsA(isA<AuthException>()),
    );
    expect(requests.any((r) => r.path.endsWith('delete_own_account')), isFalse);
    expect(accounts.currentUser?.id, _userId);
  });

  test(
    'falha de revogação remota não restaura a sessão local ao sair',
    () async {
      await accounts.signIn('person@example.com', 'password-123');
      rejectLogout = true;
      await accounts.signOut();
      expect(accounts.currentUser, isNull);
    },
  );

  test(
    'exclusão reautentica, usa RPC sem ID fornecido e encerra a sessão',
    () async {
      await accounts.signIn('person@example.com', 'password-123');
      requests.clear();
      await accounts.deleteAccount('password-123');
      expect(requests.map((r) => r.path), [
        '/auth/v1/token',
        '/rest/v1/rpc/delete_own_account',
        '/auth/v1/logout',
      ]);
      expect(requests[1].body, isNull);
      expect(accounts.currentUser, isNull);
    },
  );
}
