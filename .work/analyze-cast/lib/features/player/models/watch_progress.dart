import '../../../plugin_engine/models/content_item.dart';

class WatchProgress {
  const WatchProgress({
    required this.item,
    required this.position,
    required this.duration,
    required this.lastWatched,
    this.season,
    this.episode,
    this.server,
  });

  final ContentItem item;
  final Duration position;
  final Duration duration;
  final DateTime lastWatched;
  final int? season;
  final int? episode;

  /// Provider name, independent of its current position in the source list.
  final String? server;

  String get key =>
      '${item.pluginId}:${item.type.value}:${item.id}:${season ?? 0}:${episode ?? 0}';

  double? get progress {
    if (duration <= Duration.zero) return null;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'item': item.toJson(),
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'lastWatched': lastWatched.toIso8601String(),
    'season': season,
    'episode': episode,
    'server': server,
  };

  factory WatchProgress.fromJson(Map<String, dynamic> json) {
    final itemJson = json['item'];
    if (itemJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid watch history item');
    }
    final pluginId = itemJson['pluginId']?.toString() ?? '';
    final lastWatched = DateTime.tryParse(
      json['lastWatched']?.toString() ?? '',
    );
    if (pluginId.isEmpty || lastWatched == null) {
      throw const FormatException('Invalid watch history metadata');
    }

    return WatchProgress(
      item: ContentItem.fromJson(itemJson, pluginId),
      position: Duration(milliseconds: _readInt(json['positionMs'])),
      duration: Duration(milliseconds: _readInt(json['durationMs'])),
      lastWatched: lastWatched,
      season: _optionalInt(json['season']),
      episode: _optionalInt(json['episode']),
      server:
          json['server'] is String &&
              (json['server'] as String).trim().isNotEmpty
          ? json['server'] as String
          : null,
    );
  }

  static int _readInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  static int? _optionalInt(dynamic value) => value == null
      ? null
      : value is num
      ? value.toInt()
      : int.tryParse(value.toString());
}
