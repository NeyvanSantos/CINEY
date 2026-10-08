import 'dart:async';
import 'package:cinemax/features/auth/models/account_user.dart';
import 'package:cinemax/features/auth/models/tv_pairing_request.dart';
import 'package:cinemax/features/auth/services/account_repository.dart';
import 'package:cinemax/features/favorites/services/favorites_repository.dart';
import 'package:cinemax/plugin_engine/models/content_item.dart';

class FakeAccounts implements AccountRepository {
  @override
  bool isConfigured = true;
  @override
  AccountUser? currentUser;
  final changes = StreamController<AccountUser?>.broadcast();
  final calls = <String>[];
  final errors = <String, Object>{};
  Completer<void>? pendingLogin;
  String? lastEmail;
  String name = 'Pessoa de teste';
  bool signUpCreatesSession = false;
  bool tvPairingApproved = false;

  @override
  Stream<AccountUser?> get userChanges => changes.stream;

  void emit(AccountUser? user) {
    currentUser = user;
    changes.add(user);
  }

  void _call(String operation) {
    calls.add(operation);
    if (errors[operation] case final error?) throw error;
  }

  @override
  Future<void> signIn(String email, String password) async {
    _call('signIn');
    lastEmail = email;
    await pendingLogin?.future;
    emit(AccountUser(id: 'user-a', email: email));
  }

  @override
  Future<bool> signUp(String name, String email, String password) async {
    _call('signUp');
    lastEmail = email;
    if (signUpCreatesSession) {
      emit(AccountUser(id: 'user-a', email: email));
    }
    return signUpCreatesSession;
  }

  @override
  Future<void> confirmEmail(String email, String code) async {
    _call('confirmEmail');
    lastEmail = email;
    emit(AccountUser(id: 'user-a', email: email));
  }

  @override
  Future<void> resendConfirmation(String email) async {
    _call('resendConfirmation');
    lastEmail = email;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    _call('requestPasswordReset');
    lastEmail = email;
  }

  @override
  Future<void> verifyRecovery(String email, String code) async {
    _call('verifyRecovery');
    lastEmail = email;
    emit(AccountUser(id: 'user-a', email: email));
  }

  @override
  Future<void> updatePassword(String password) async => _call('updatePassword');

  @override
  Future<String> getDisplayName(String userId) async {
    _call('getDisplayName');
    return name;
  }

  @override
  Future<void> updateDisplayName(String name) async {
    _call('updateDisplayName');
    this.name = name;
  }

  @override
  Future<void> signOut() async {
    _call('signOut');
    emit(null);
  }

  @override
  Future<void> deleteAccount(String password) async {
    _call('deleteAccount');
    emit(null);
  }

  @override
  Future<TvPairingRequest> createTvPairing() async {
    _call('createTvPairing');
    return TvPairingRequest(
      id: 'pairing-id',
      secret: 'pairing-secret',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<void> approveTvPairing(String qrPayload) async =>
      _call('approveTvPairing');

  @override
  Future<bool> checkTvPairing(TvPairingRequest request) async {
    _call('checkTvPairing');
    if (tvPairingApproved) {
      emit(const AccountUser(id: 'user-a', email: 'a@example.com'));
    }
    return tvPairingApproved;
  }
}

class FakeFavorites implements FavoritesRepository {
  final data = <String, List<ContentItem>>{};
  final changes = StreamController<String>.broadcast();
  int writes = 0;
  Object? writeError;

  @override
  Stream<List<ContentItem>> watchFavorites(String userId) async* {
    yield List.of(data[userId] ?? []);
    yield* changes.stream
        .where((id) => id == userId)
        .map((_) => List.of(data[userId] ?? []));
  }

  @override
  Future<void> setFavorite(
    String userId,
    ContentItem item, {
    required bool saved,
  }) async {
    writes++;
    if (writeError case final error?) throw error;
    final items = data.putIfAbsent(userId, () => []);
    items.removeWhere((current) => isSameContent(current, item));
    if (saved) items.add(item);
    changes.add(userId);
  }
}
