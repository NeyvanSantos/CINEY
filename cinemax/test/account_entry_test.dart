import 'package:cinemax/cinemax_app.dart';
import 'package:cinemax/core/routes/app_router.dart';
import 'package:cinemax/features/auth/models/account_user.dart';
import 'package:cinemax/features/auth/presentation/auth_screen.dart';
import 'package:cinemax/features/auth/services/account_repository.dart';
import 'package:cinemax/features/favorites/services/favorites_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_accounts.dart';

const _user = AccountUser(id: 'user-a', email: 'a@example.com');

Future<GoRouter> _mount(
  WidgetTester tester,
  FakeAccounts accounts, {
  String initial = '/onboarding',
  bool isTv = false,
}) async {
  tester.view.physicalSize = const Size(1000, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final favorites = FakeFavorites();
  final container = ProviderContainer(
    overrides: [
      accountRepositoryProvider.overrideWithValue(accounts),
      favoritesRepositoryProvider.overrideWithValue(favorites),
    ],
  );
  final router = container.read(appRouterProvider(isTv));
  router.go(initial);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await favorites.changes.close();
    await accounts.changes.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: CinemaxApp(isTv: isTv),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _path(GoRouter router) => router.state.uri.path;

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

  for (final isTv in [false, true]) {
    testWidgets('sem conta, rotas do app ficam bloqueadas (TV: $isTv)', (
      tester,
    ) async {
      final accounts = FakeAccounts();
      final router = await _mount(tester, accounts, isTv: isTv);
      expect(find.text('Criar sua conta'), findsOneWidget);
      expect(find.text('Já tenho uma conta'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);

      for (final location in [
        '/home',
        '/search',
        '/downloads',
        '/profile',
        '/account',
        '/favorites',
        '/onboarding',
        '/extensions',
        '/section',
        '/logs',
        '/details/42/source-a',
        '/player/42/source-a',
        '/tv-pair-scan',
      ]) {
        router.go(location);
        await tester.pumpAndSettle();
        expect(_path(router), '/auth', reason: location);
        expect(find.byType(AuthScreen), findsOneWidget);
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_path(router), '/auth');
      expect(router.canPop(), isFalse);
    });

    testWidgets('sessão restaurada dispensa cadastro (TV: $isTv)', (
      tester,
    ) async {
      final accounts = FakeAccounts()..currentUser = _user;
      final router = await _mount(
        tester,
        accounts,
        initial: '/account',
        isTv: isTv,
      );
      expect(_path(router), '/account');
      expect(find.text('Minha conta'), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);
      expect(accounts.calls, isNot(contains('signIn')));
      expect(accounts.calls, isNot(contains('signUp')));
    });
  }

  testWidgets('cadastro só libera configuração inicial após confirmar e-mail', (
    tester,
  ) async {
    final accounts = FakeAccounts();
    final router = await _mount(tester, accounts);
    await _fill(tester, 'Nome', 'Pessoa de teste');
    await _fill(tester, 'E-mail', 'pessoa@example.com');
    await _fill(tester, 'Nova senha', 'senha-segura-123');
    await _fill(tester, 'Confirmar senha', 'senha-segura-123');
    await _tap(tester, 'Criar conta');
    expect(_path(router), '/auth');
    expect(accounts.currentUser, isNull);
    expect(find.text('Confirmar e-mail'), findsOneWidget);
    await _fill(tester, 'Código recebido por e-mail', '123456');
    await _tap(tester, 'Confirmar código');
    expect(_path(router), '/onboarding');
    expect(accounts.currentUser?.id, _user.id);
  });

  testWidgets('cadastro com sessão imediata libera configuração inicial', (
    tester,
  ) async {
    final accounts = FakeAccounts()..signUpCreatesSession = true;
    final router = await _mount(tester, accounts);
    await _fill(tester, 'Nome', 'Pessoa de teste');
    await _fill(tester, 'E-mail', 'pessoa@example.com');
    await _fill(tester, 'Nova senha', 'senha-segura-123');
    await _fill(tester, 'Confirmar senha', 'senha-segura-123');
    await _tap(tester, 'Criar conta');
    expect(_path(router), '/onboarding');
  });

  testWidgets('sair da conta bloqueia novamente as rotas e o retorno', (
    tester,
  ) async {
    final accounts = FakeAccounts()..currentUser = _user;
    final router = await _mount(tester, accounts, initial: '/account');
    await _tap(tester, 'Sair desta conta');
    expect(accounts.currentUser, isNull);
    expect(_path(router), '/auth');
    expect(find.text('Entrar no CiNey'), findsOneWidget);
    expect(router.canPop(), isFalse);
    router.go('/profile');
    await tester.pumpAndSettle();
    expect(_path(router), '/auth');
  });

  testWidgets('perder sessão redireciona sem precisar navegar', (tester) async {
    final accounts = FakeAccounts()..currentUser = _user;
    final router = await _mount(tester, accounts, initial: '/account');
    accounts.emit(null);
    await tester.pumpAndSettle();
    expect(_path(router), '/auth');
    expect(find.text('Entrar no CiNey'), findsOneWidget);
    expect(find.text('Minha conta'), findsNothing);
  });

  testWidgets('contas indisponíveis não liberam acesso ao catálogo', (
    tester,
  ) async {
    final accounts = FakeAccounts()..isConfigured = false;
    final router = await _mount(tester, accounts, initial: '/home');
    expect(_path(router), '/auth');
    expect(find.text('Contas ainda indisponíveis'), findsOneWidget);
    expect(find.text('Explorar catálogo'), findsNothing);
    expect(accounts.calls, isEmpty);
  });

  testWidgets('recuperação mantém nova senha mesmo depois de criar sessão', (
    tester,
  ) async {
    final accounts = FakeAccounts();
    final router = await _mount(tester, accounts);
    await _tap(tester, 'Já tenho uma conta');
    await _fill(tester, 'E-mail', 'pessoa@example.com');
    await _tap(tester, 'Esqueci minha senha');
    await _tap(tester, 'Enviar código');
    await _fill(tester, 'Código recebido por e-mail', '123456');
    await _tap(tester, 'Confirmar código');
    expect(accounts.currentUser?.id, _user.id);
    expect(_path(router), '/auth');
    expect(find.text('Escolher nova senha'), findsOneWidget);
    await _fill(tester, 'Nova senha', 'senha-nova-123');
    await _fill(tester, 'Confirmar senha', 'senha-nova-123');
    await _tap(tester, 'Salvar nova senha');
    expect(_path(router), '/onboarding');
  });

  testWidgets('TV permite pareamento na entrada e libera após autorização', (
    tester,
  ) async {
    final accounts = FakeAccounts();
    final router = await _mount(tester, accounts, isTv: true);
    final pairingButton = find.text('Conectar com Android');
    await tester.ensureVisible(pairingButton);
    await tester.tap(pairingButton);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(_path(router), '/tv-pair');
    expect(find.text('Conectar esta TV'), findsOneWidget);
    expect(accounts.currentUser, isNull);
    accounts.tvPairingApproved = true;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(_path(router), '/onboarding');
    expect(accounts.currentUser?.id, _user.id);
  });

  testWidgets('celular não permite pareamento de TV sem autenticação', (
    tester,
  ) async {
    final accounts = FakeAccounts();
    final router = await _mount(tester, accounts);
    router.go('/tv-pair');
    await tester.pumpAndSettle();
    expect(_path(router), '/auth');
    expect(find.text('Conectar com Android'), findsNothing);
    expect(accounts.calls, isEmpty);
  });
}
