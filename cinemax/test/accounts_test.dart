import 'dart:async';
import 'dart:convert';
import 'package:cinemax/core/config/account_config.dart';
import 'package:cinemax/core/services/app_logger.dart';
import 'package:cinemax/features/auth/models/account_user.dart';
import 'package:cinemax/features/auth/presentation/account_screen.dart';
import 'package:cinemax/features/auth/presentation/auth_screen.dart';
import 'package:cinemax/features/auth/services/account_messages.dart';
import 'package:cinemax/features/auth/services/account_repository.dart';
import 'package:cinemax/features/favorites/presentation/favorite_button.dart';
import 'package:cinemax/features/favorites/services/favorites_repository.dart';
import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/fake_accounts.dart';

const _movie = ContentItem(
  id: '42',
  pluginId: 'source-a',
  type: ContentType.movie,
  title: 'Filme',
  posterUrl: '',
);
const _userA = AccountUser(id: 'user-a', email: 'a@example.com');
const _userB = AccountUser(id: 'user-b', email: 'b@example.com');

Future<GoRouter> _mount(
  WidgetTester tester,
  FakeAccounts accounts, {
  String initial = '/auth',
  bool requireAccount = false,
  bool startWithSignup = false,
}) async {
  tester.view.reset();
  tester.view.physicalSize = const Size(1000, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/auth',
        builder: (_, _) => AuthScreen(
          requireAccount: requireAccount,
          startWithSignup: startWithSignup,
        ),
      ),
      GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('Perfil de destino')),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Catálogo de destino')),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const Scaffold(body: Text('Configuração inicial')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accountRepositoryProvider.overrideWithValue(accounts)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, String label, String value) =>
    tester.enterText(find.widgetWithText(TextFormField, label), value);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'configuração recusa chaves secretas e aceita somente chaves públicas',
    () {
      String jwt(String role) =>
          'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.signature';
      const url = 'https://example.supabase.co';
      expect(
        const AccountConfig(
          url: url,
          publicKey: 'sb_secret_private',
        ).isConfigured,
        isFalse,
      );
      expect(
        AccountConfig(url: url, publicKey: jwt('service_role')).isConfigured,
        isFalse,
      );
      expect(
        AccountConfig(url: url, publicKey: jwt('anon')).isConfigured,
        isTrue,
      );
      expect(
        const AccountConfig(
          url: url,
          publicKey: 'broken.jwt.token',
        ).isConfigured,
        isFalse,
      );
      expect(
        const AccountConfig(
          url: 'http://example.com',
          publicKey: 'sb_publishable_example',
        ).isConfigured,
        isFalse,
      );
      expect(
        const AccountConfig(
          url: url,
          publicKey: 'sb_publishable_example',
        ).isConfigured,
        isTrue,
      );
    },
  );

  test('mensagens de autenticação não expõem detalhes sensíveis nos logs', () {
    accountErrorMessage(
      const AuthException(
        'private-token a@example.com',
        code: 'invalid_credentials',
      ),
    );
    final entry = AppLogger.entries.last;
    expect(entry.message, isNot(contains('private-token')));
    expect(entry.message, isNot(contains('a@example.com')));
  });

  testWidgets(
    'cadastro valida confirmação de senha e preserva e-mail até o código',
    (tester) async {
      final accounts = FakeAccounts();
      addTearDown(accounts.changes.close);
      await _mount(tester, accounts);
      await _tap(tester, 'Criar conta');
      await _fill(tester, 'Nome', 'Pessoa de teste');
      await _fill(tester, 'E-mail', 'pessoa@example.com');
      await _fill(tester, 'Nova senha', 'senha-segura-123');
      await _fill(tester, 'Confirmar senha', 'diferente');
      await _tap(tester, 'Criar conta');
      expect(accounts.calls, isNot(contains('signUp')));
      expect(find.text('As senhas precisam ser iguais.'), findsOneWidget);
      await _fill(tester, 'Confirmar senha', 'senha-segura-123');
      await _tap(tester, 'Criar conta');
      expect(find.text('Confirmar e-mail'), findsOneWidget);
      expect(find.text('pessoa@example.com'), findsOneWidget);
      await _tap(tester, 'Reenviar código');
      expect(accounts.lastEmail, 'pessoa@example.com');
      await _fill(tester, 'Código recebido por e-mail', '123456');
      await _tap(tester, 'Confirmar código');
      expect(accounts.lastEmail, 'pessoa@example.com');
      expect(find.text('Perfil de destino'), findsOneWidget);
    },
  );

  testWidgets('senha incorreta mantém o formulário; login posterior conclui', (
    tester,
  ) async {
    final accounts = FakeAccounts()
      ..errors['signIn'] = const AuthException(
        'private',
        code: 'invalid_credentials',
      );
    addTearDown(accounts.changes.close);
    await _mount(tester, accounts);
    await _fill(tester, 'E-mail', 'pessoa@example.com');
    await _fill(tester, 'Senha', 'errada');
    await _tap(tester, 'Entrar');
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(find.text('Perfil de destino'), findsNothing);
    accounts.errors.clear();
    await _tap(tester, 'Entrar');
    expect(find.text('Perfil de destino'), findsOneWidget);
  });

  testWidgets(
    'recuperação exige código e permite repetir atualização sem reutilizar OTP',
    (tester) async {
      final accounts = FakeAccounts()
        ..errors['verifyRecovery'] = const AuthException(
          'expired',
          code: 'otp_expired',
        );
      addTearDown(accounts.changes.close);
      await _mount(tester, accounts);
      await _fill(tester, 'E-mail', 'pessoa@example.com');
      await _tap(tester, 'Esqueci minha senha');
      await _tap(tester, 'Enviar código');
      expect(accounts.lastEmail, 'pessoa@example.com');
      await _fill(tester, 'Código recebido por e-mail', '123456');
      await _tap(tester, 'Confirmar código');
      expect(
        find.text('Código inválido ou expirado. Solicite outro código.'),
        findsOneWidget,
      );
      expect(find.text('Salvar nova senha'), findsNothing);
      accounts.errors.clear();
      await _tap(tester, 'Confirmar código');
      await _fill(tester, 'Nova senha', 'nova-senha-123');
      await _fill(tester, 'Confirmar senha', 'nova-senha-123');
      accounts.errors['updatePassword'] = const AuthException(
        'same',
        code: 'same_password',
      );
      await _tap(tester, 'Salvar nova senha');
      expect(
        find.text('Escolha uma senha diferente da atual.'),
        findsOneWidget,
      );
      accounts.errors.clear();
      await _tap(tester, 'Salvar nova senha');
      expect(
        accounts.calls.where((call) => call == 'verifyRecovery').length,
        2,
      );
      expect(
        accounts.calls.where((call) => call == 'updatePassword').length,
        2,
      );
      expect(find.text('Perfil de destino'), findsOneWidget);
    },
  );

  testWidgets(
    'envio em andamento bloqueia cliques duplicados e mantém retorno à origem',
    (tester) async {
      final accounts = FakeAccounts()..pendingLogin = Completer<void>();
      addTearDown(accounts.changes.close);
      final router = await _mount(tester, accounts, initial: '/home');
      unawaited(router.push('/auth'));
      await tester.pumpAndSettle();
      await _fill(tester, 'E-mail', 'pessoa@example.com');
      await _fill(tester, 'Senha', 'senha-123');
      await tester.tap(find.text('Entrar'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(accounts.calls.where((call) => call == 'signIn').length, 1);
      accounts.pendingLogin!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Catálogo de destino'), findsOneWidget);
    },
  );

  testWidgets('contas sem configuração mantêm o acesso bloqueado', (
    tester,
  ) async {
    final accounts = FakeAccounts()..isConfigured = false;
    addTearDown(accounts.changes.close);
    await _mount(tester, accounts);
    expect(find.text('Contas ainda indisponíveis'), findsOneWidget);
    expect(find.text('Explorar catálogo'), findsNothing);
    expect(find.text('Catálogo de destino'), findsNothing);
    expect(accounts.calls, isEmpty);
  });

  testWidgets(
    'login na entrada retoma o catálogo com configuração já concluída',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      final accounts = FakeAccounts();
      addTearDown(accounts.changes.close);
      await _mount(
        tester,
        accounts,
        requireAccount: true,
        startWithSignup: true,
      );
      await _tap(tester, 'Já tenho uma conta');
      await _fill(tester, 'E-mail', 'pessoa@example.com');
      await _fill(tester, 'Senha', 'senha-123');
      await _tap(tester, 'Entrar');
      expect(find.text('Catálogo de destino'), findsOneWidget);
      expect(find.text('Configuração inicial'), findsNothing);
    },
  );

  testWidgets('perfil salva nome e pede senha antes de excluir', (
    tester,
  ) async {
    final accounts = FakeAccounts()..currentUser = _userA;
    addTearDown(accounts.changes.close);
    await _mount(tester, accounts, initial: '/account');
    await _fill(tester, 'Nome', 'Novo nome');
    await _tap(tester, 'Salvar nome');
    expect(accounts.name, 'Novo nome');
    await _tap(tester, 'Excluir conta');
    await _tap(tester, 'Excluir definitivamente');
    expect(accounts.calls, isNot(contains('deleteAccount')));
    expect(find.text('Informe sua senha.'), findsOneWidget);
    await _tap(tester, 'Cancelar');
    await _tap(tester, 'Excluir conta');
    await _fill(tester, 'Senha atual', 'senha-segura');
    await _tap(tester, 'Excluir definitivamente');
    expect(accounts.calls, contains('deleteAccount'));
    expect(find.text('Perfil de destino'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('botão de login aceita a tecla de confirmação do controle', (
    tester,
  ) async {
    final accounts = FakeAccounts();
    addTearDown(accounts.changes.close);
    await _mount(tester, accounts);
    await _fill(tester, 'E-mail', 'pessoa@example.com');
    await _fill(tester, 'Senha', 'senha-123');
    Focus.of(tester.element(find.text('Entrar'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(accounts.calls.where((call) => call == 'signIn').length, 1);
    expect(find.text('Perfil de destino'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'sair ou trocar de usuário descarta favoritos da conta anterior',
    () async {
      final accounts = FakeAccounts()..currentUser = _userA;
      final favorites = FakeFavorites()..data['user-a'] = [_movie];
      final container = ProviderContainer(
        overrides: [
          accountRepositoryProvider.overrideWithValue(accounts),
          favoritesRepositoryProvider.overrideWithValue(favorites),
        ],
      );
      final subscription = container.listen(favoritesProvider, (_, _) {});
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await accounts.changes.close();
        await favorites.changes.close();
      });
      await container.read(accountUserProvider.future);
      await container.pump();
      expect(await container.read(favoritesProvider.future), [_movie]);
      accounts.emit(_userB);
      await container.pump();
      expect(await container.read(favoritesProvider.future), isEmpty);
      accounts.emit(null);
      await container.pump();
      expect(await container.read(favoritesProvider.future), isEmpty);
      favorites.changes.add('user-a');
      await container.pump();
      expect(container.read(favoritesProvider).valueOrNull, isEmpty);
    },
  );

  testWidgets(
    'favoritos só indicam sucesso após salvar; falha preserva estado',
    (tester) async {
      final accounts = FakeAccounts()..currentUser = _userA;
      final favorites = FakeFavorites()..writeError = StateError('offline');
      addTearDown(accounts.changes.close);
      addTearDown(favorites.changes.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountRepositoryProvider.overrideWithValue(accounts),
            favoritesRepositoryProvider.overrideWithValue(favorites),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FavoriteButton(item: _movie)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favoritar'));
      await tester.pumpAndSettle();
      expect(find.text('Adicionado aos favoritos.'), findsNothing);
      expect(find.byTooltip('Favoritar'), findsOneWidget);
      favorites.writeError = null;
      await tester.tap(find.byTooltip('Favoritar'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remover dos favoritos'), findsOneWidget);
      await tester.tap(find.byTooltip('Remover dos favoritos'));
      await tester.pumpAndSettle();
      expect(favorites.data['user-a'], isEmpty);
      expect(find.byTooltip('Favoritar'), findsOneWidget);
    },
  );
}
