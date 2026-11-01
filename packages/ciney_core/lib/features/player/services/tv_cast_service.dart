import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class TvCastPlaybackCommand {
  const TvCastPlaybackCommand({
    required this.contentId,
    required this.pluginId,
    required this.title,
    required this.contentTitle,
    required this.posterUrl,
    required this.mediaType,
    required this.server,
    required this.resumePositionMs,
    this.season,
    this.episode,
  });

  final String contentId;
  final String pluginId;
  final String title;
  final String contentTitle;
  final String posterUrl;
  final String mediaType;
  final String server;
  final int resumePositionMs;
  final int? season;
  final int? episode;

  Map<String, Object> toJson() => {
    'version': 1,
    'action': 'play',
    'contentId': contentId,
    'pluginId': pluginId,
    'title': title,
    'contentTitle': contentTitle,
    'posterUrl': posterUrl,
    'mediaType': mediaType,
    'server': server,
    'resumePositionMs': resumePositionMs,
    'season': ?season,
    'episode': ?episode,
  };

  static TvCastPlaybackCommand? tryParse(Object? payload) {
    if (payload is! Map) return null;
    try {
      final data = Map<String, dynamic>.from(payload);
      if (data['version'] != 1 || data['action'] != 'play') return null;

      String? text(String key, {int maxLength = 300}) {
        final value = data[key];
        if (value is! String || value.isEmpty || value.length > maxLength) {
          return null;
        }
        return value;
      }

      final contentId = text('contentId', maxLength: 160);
      final pluginId = text('pluginId', maxLength: 120);
      final title = text('title');
      final contentTitle = text('contentTitle');
      final mediaType = text('mediaType', maxLength: 24);
      final server = text('server', maxLength: 80);
      final posterUrl = data['posterUrl'];
      final position = data['resumePositionMs'];
      final season = data['season'];
      final episode = data['episode'];
      if (contentId == null ||
          pluginId == null ||
          title == null ||
          contentTitle == null ||
          mediaType == null ||
          server == null ||
          !const {'movie', 'series', 'anime', 'dorama'}.contains(mediaType) ||
          posterUrl is! String ||
          posterUrl.length > 2048 ||
          position is! int ||
          position < 0 ||
          (season != null && (season is! int || season < 1)) ||
          (episode != null && (episode is! int || episode < 1))) {
        return null;
      }

      return TvCastPlaybackCommand(
        contentId: contentId,
        pluginId: pluginId,
        title: title,
        contentTitle: contentTitle,
        posterUrl: posterUrl,
        mediaType: mediaType,
        server: server,
        resumePositionMs: position,
        season: season as int?,
        episode: episode as int?,
      );
    } on TypeError {
      return null;
    }
  }

  String get playerLocation => Uri(
    pathSegments: ['', 'player', contentId, pluginId],
    queryParameters: {
      'title': title,
      'contentTitle': contentTitle,
      'poster': posterUrl,
      'type': mediaType,
      'server': server,
      'resumePositionMs': '$resumePositionMs',
      if (season != null) 'season': '$season',
      if (episode != null) 'episode': '$episode',
    },
  ).toString();
}

class TvCastService {
  const TvCastService(this.client);

  final SupabaseClient client;

  static String topicForUser(String userId) => 'ciney-cast:$userId';

  RealtimeChannel listen({
    required String userId,
    required void Function(TvCastPlaybackCommand command) onCommand,
    void Function(RealtimeSubscribeStatus status, Object? error)? onStatus,
  }) {
    return client
        .channel(
          topicForUser(userId),
          opts: const RealtimeChannelConfig(private: true),
        )
        .onBroadcast(
          event: 'play',
          callback: (payload) {
            final command = TvCastPlaybackCommand.tryParse(payload);
            if (command != null) onCommand(command);
          },
        )
        .subscribe(onStatus);
  }

  Future<void> send(TvCastPlaybackCommand command) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('A sessão CiNey não está autenticada.');
    }

    final channel = client.channel(
      topicForUser(userId),
      opts: const RealtimeChannelConfig(private: true),
    );
    final subscribed = Completer<void>();
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed &&
          !subscribed.isCompleted) {
        subscribed.complete();
      } else if (error != null && !subscribed.isCompleted) {
        subscribed.completeError(error);
      }
    });

    try {
      await subscribed.future.timeout(const Duration(seconds: 12));
      await channel.sendBroadcastMessage(
        event: 'play',
        payload: command.toJson(),
      );
    } finally {
      await channel.unsubscribe();
      await client.removeChannel(channel);
    }
  }
}
