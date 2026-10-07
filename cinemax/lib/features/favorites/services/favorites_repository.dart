import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../plugin_engine/models/content_item.dart';
import '../../auth/services/account_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => SupabaseFavoritesRepository(ref.watch(supabaseClientProvider)),
);

final favoritesProvider = StreamProvider.autoDispose<List<ContentItem>>((ref) {
  final userId = ref.watch(
    accountUserProvider.select((state) => state.valueOrNull?.id),
  );
  if (userId == null) return Stream.value(const []);
  return ref.watch(favoritesRepositoryProvider).watchFavorites(userId);
});

abstract class FavoritesRepository {
  Stream<List<ContentItem>> watchFavorites(String userId);
  Future<void> setFavorite(
    String userId,
    ContentItem item, {
    required bool saved,
  });
}

bool isSameContent(ContentItem a, ContentItem b) =>
    a.id == b.id && a.pluginId == b.pluginId && a.type == b.type;

class SupabaseFavoritesRepository implements FavoritesRepository {
  SupabaseFavoritesRepository(this.client);

  final SupabaseClient? client;

  SupabaseClient get _client =>
      client ?? (throw StateError('Contas indisponíveis'));

  @override
  Stream<List<ContentItem>> watchFavorites(String userId) => _client
      .from('favorites')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .map(
        (rows) => rows
            .map(
              (row) => ContentItem(
                id: row['content_id'] as String,
                pluginId: row['plugin_id'] as String,
                type: ContentType.fromString(row['content_type'] as String),
                title: row['title'] as String,
                posterUrl: row['poster_url'] as String,
              ),
            )
            .toList(growable: false),
      );

  @override
  Future<void> setFavorite(
    String userId,
    ContentItem item, {
    required bool saved,
  }) async {
    if (_client.auth.currentUser?.id != userId) {
      throw StateError('Sua conta mudou. Entre novamente.');
    }
    final identity = {
      'user_id': userId,
      'content_id': item.id,
      'plugin_id': item.pluginId,
      'content_type': item.type.value,
    };
    if (saved) {
      await _client.from('favorites').upsert({
        ...identity,
        'title': item.title,
        'poster_url': item.posterUrl,
      }, onConflict: 'user_id,content_id,plugin_id,content_type');
    } else {
      await _client.from('favorites').delete().match(identity);
    }
  }
}
