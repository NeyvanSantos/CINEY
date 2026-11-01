import 'package:cinemax/features/auth/services/account_repository.dart';
import 'package:cinemax/features/auth/models/account_user.dart';
import 'package:cinemax/features/player/services/watch_history_repository.dart';
import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_accounts.dart';

void main() {
  test(
    'cada conta recupera somente o próprio histórico no mesmo dispositivo',
    () async {
      SharedPreferences.setMockInitialValues({});
      const item = ContentItem(
        id: 'film',
        title: 'Filme',
        posterUrl: '',
        type: ContentType.movie,
        pluginId: 'test',
      );
      Future<List<String>> useAccount(String id, {bool write = false}) async {
        final accounts = FakeAccounts()
          ..currentUser = AccountUser(id: id, email: '$id@example.test');
        final container = ProviderContainer(
          overrides: [accountRepositoryProvider.overrideWithValue(accounts)],
        );
        try {
          final history = container.read(watchHistoryRepositoryProvider);
          if (write) await history.markStarted(item);
          return (await history.load()).map((entry) => entry.item.id).toList();
        } finally {
          container.dispose();
          await accounts.changes.close();
        }
      }

      expect(await useAccount('alice', write: true), ['film']);
      expect(await useAccount('bob'), isEmpty);
      expect(await useAccount('alice'), ['film']);
    },
  );
}
