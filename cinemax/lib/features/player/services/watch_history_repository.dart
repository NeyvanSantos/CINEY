import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../plugin_engine/models/content_item.dart';
import '../models/watch_progress.dart';

final watchHistoryRepositoryProvider = Provider<WatchHistoryRepository>(
  (ref) => WatchHistoryRepository(),
);

final watchHistoryProvider = FutureProvider.autoDispose<List<WatchProgress>>(
  (ref) => ref.read(watchHistoryRepositoryProvider).load(),
);

class WatchHistoryRepository {
  WatchHistoryRepository({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const _storageKey = 'watch-history-v1';
  static const _maxItems = 30;

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<List<WatchProgress>> load() async {
    final preferences = await _preferencesLoader();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null) return const [];

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];
      final entries = <WatchProgress>[];
      for (final value in decoded) {
        if (value is! Map<String, dynamic>) continue;
        try {
          entries.add(WatchProgress.fromJson(value));
        } on FormatException {
          continue;
        }
      }
      entries.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
      return entries;
    } on FormatException {
      return const [];
    }
  }

  Future<void> markStarted(
    ContentItem item, {
    int? season,
    int? episode,
  }) async {
    final entries = await load();
    final key = _key(item, season, episode);
    final previous = entries.where((entry) => entry.key == key).firstOrNull;
    final updated = WatchProgress(
      item: item,
      position: previous?.position ?? Duration.zero,
      duration: previous?.duration ?? Duration.zero,
      lastWatched: DateTime.now(),
      season: season,
      episode: episode,
    );
    await _store([updated, ...entries.where((entry) => entry.key != key)]);
  }

  Future<void> saveProgress(
    ContentItem item, {
    required Duration position,
    required Duration duration,
    int? season,
    int? episode,
  }) async {
    if (position < const Duration(seconds: 5)) return;
    final entries = await load();
    final key = _key(item, season, episode);
    final remaining = entries.where((entry) => entry.key != key).toList();
    final isComplete =
        duration > Duration.zero &&
        position.inMilliseconds >= duration.inMilliseconds * 0.95;
    if (!isComplete) {
      remaining.add(
        WatchProgress(
          item: item,
          position: position,
          duration: duration,
          lastWatched: DateTime.now(),
          season: season,
          episode: episode,
        ),
      );
    }
    await _store(remaining);
  }

  Future<void> _store(List<WatchProgress> entries) async {
    entries.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
    final preferences = await _preferencesLoader();
    await preferences.setString(
      _storageKey,
      jsonEncode(
        entries.take(_maxItems).map((entry) => entry.toJson()).toList(),
      ),
    );
  }

  String _key(ContentItem item, int? season, int? episode) =>
      '${item.pluginId}:${item.type.value}:${item.id}:${season ?? 0}:${episode ?? 0}';
}
