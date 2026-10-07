import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/app_logger.dart';
import '../models/account_user.dart';
import '../models/tv_pairing_request.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => SupabaseAccountRepository(ref.watch(supabaseClientProvider)),
);

final accountUserProvider = StreamProvider<AccountUser?>((ref) async* {
  final repository = ref.watch(accountRepositoryProvider);
  yield repository.currentUser;
  yield* repository.userChanges;
});

final profileNameProvider = FutureProvider.autoDispose<String>((ref) async {
  final userId = ref.watch(
    accountUserProvider.select((state) => state.valueOrNull?.id),
  );
  if (userId == null) return '';
  return ref.watch(accountRepositoryProvider).getDisplayName(userId);
});

abstract class AccountRepository {
  bool get isConfigured;
  AccountUser? get currentUser;
  Stream<AccountUser?> get userChanges;
  Future<void> signIn(String email, String password);
  Future<bool> signUp(String name, String email, String password);
  Future<void> confirmEmail(String email, String code);
  Future<void> resendConfirmation(String email);
  Future<void> requestPasswordReset(String email);
  Future<void> verifyRecovery(String email, String code);
  Future<void> updatePassword(String password);
  Future<String> getDisplayName(String userId);
  Future<void> updateDisplayName(String name);
  Future<void> signOut();
  Future<void> deleteAccount(String password);
  Future<TvPairingRequest> createTvPairing();
  Future<void> approveTvPairing(String qrPayload);
  Future<bool> checkTvPairing(TvPairingRequest request);
}

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this.client);
  final SupabaseClient? client;

  SupabaseClient get _client =>
      client ?? (throw StateError('Contas indisponíveis'));

  AccountUser? _user(User? user) =>
      user == null ? null : AccountUser(id: user.id, email: user.email ?? '');

  @override
  bool get isConfigured => client != null;

  @override
  AccountUser? get currentUser => _user(client?.auth.currentUser);

  @override
  Stream<AccountUser?> get userChanges => client == null
      ? const Stream.empty()
      : _client.auth.onAuthStateChange.map(
          (event) => _user(event.session?.user),
        );

  @override
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<bool> signUp(String name, String email, String password) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
    );
    return response.session != null;
  }

  @override
  Future<void> confirmEmail(String email, String code) async {
    await _client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.signup,
    );
  }

  @override
  Future<void> resendConfirmation(String email) async {
    await _client.auth.resend(email: email.trim(), type: OtpType.signup);
  }

  @override
  Future<void> requestPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email.trim());

  @override
  Future<void> verifyRecovery(String email, String code) async {
    await _client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.recovery,
    );
  }

  @override
  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<String> getDisplayName(String userId) async {
    final row = await _client
        .from('profiles')
        .select('display_name')
        .eq('id', userId)
        .single();
    return row['display_name'] as String;
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Entre na sua conta novamente.');
    await _client
        .from('profiles')
        .update({'display_name': name.trim()})
        .eq('id', user.id)
        .select()
        .single();
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } on AuthException catch (error) {
      // The SDK clears the local session before trying to revoke it remotely.
      // Offline logout (and logout after account deletion) still succeeds locally.
      if (_client.auth.currentSession != null) rethrow;
      AppLogger.warn(
        'Sessão local encerrada; revogação remota indisponível (${error.runtimeType}).',
        tag: 'ACCOUNT',
      );
    }
  }

  @override
  Future<void> deleteAccount(String password) async {
    final user = currentUser;
    if (user == null) throw StateError('Entre na sua conta novamente.');
    await signIn(user.email, password);
    // This function derives the user ID from the JWT and cascades personal data.
    await _client.rpc('delete_own_account');
    await signOut();
  }

  @override
  Future<TvPairingRequest> createTvPairing() async {
    final response = await _client.functions.invoke(
      'tv-pairing',
      body: {'action': 'start'},
    );
    return TvPairingRequest.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  @override
  Future<void> approveTvPairing(String qrPayload) async {
    final uri = Uri.tryParse(qrPayload);
    if (uri == null || uri.scheme != 'ciney' || uri.host != 'tv-pair') {
      throw const FormatException('Este QR não é um pareamento CiNey TV.');
    }
    final id = uri.queryParameters['id'];
    final secret = uri.queryParameters['secret'];
    if (id == null || secret == null || id.isEmpty || secret.isEmpty) {
      throw const FormatException('O QR de pareamento está incompleto.');
    }
    await _client.functions.invoke(
      'tv-pairing',
      body: {'action': 'approve', 'id': id, 'secret': secret},
    );
  }

  @override
  Future<bool> checkTvPairing(TvPairingRequest request) async {
    final response = await _client.functions.invoke(
      'tv-pairing',
      body: {'action': 'poll', 'id': request.id, 'secret': request.secret},
    );
    final result = Map<String, dynamic>.from(response.data as Map);
    if (result['status'] != 'ready') return false;

    final email = result['email'] as String;
    final tokenHash = result['tokenHash'] as String;
    await _client.auth.verifyOTP(
      email: email,
      token: tokenHash,
      type: OtpType.magiclink,
    );
    try {
      await _client.functions.invoke(
        'tv-pairing',
        body: {
          'action': 'complete',
          'id': request.id,
          'secret': request.secret,
        },
      );
    } catch (error) {
      AppLogger.warn(
        'Sessão da TV criada; limpeza do pareamento pendente (${error.runtimeType}).',
        tag: 'ACCOUNT',
      );
    }
    return true;
  }
}
