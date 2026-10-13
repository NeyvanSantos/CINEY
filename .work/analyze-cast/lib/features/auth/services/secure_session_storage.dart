import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The SDK stores the serialized session here; passwords are never persisted.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage(this.key);

  final String key;
  static const _storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => _storage.read(key: key);

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: key);
}
