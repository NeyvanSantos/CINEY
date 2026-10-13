import 'package:cinemax/features/player/services/tv_cast_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const command = TvCastPlaybackCommand(
    contentId: 'tmdb_969681',
    pluginId: 'embedmovies',
    title: 'Homem-Aranha: Um Novo Dia',
    contentTitle: 'Homem-Aranha: Um Novo Dia',
    posterUrl: 'https://image.example/poster.jpg',
    mediaType: 'movie',
    server: 'EmbedMovies',
    resumePositionMs: 125000,
  );

  test('serializa um comando de reprodução e reconstrói a rota da TV', () {
    final parsed = TvCastPlaybackCommand.tryParse(command.toJson());

    expect(parsed, isNotNull);
    expect(parsed!.contentId, command.contentId);
    expect(parsed.server, 'EmbedMovies');
    expect(parsed.resumePositionMs, 125000);

    final route = Uri.parse(parsed.playerLocation);
    expect(route.path, '/player/tmdb_969681/embedmovies');
    expect(route.queryParameters['server'], 'EmbedMovies');
    expect(route.queryParameters['resumePositionMs'], '125000');
  });

  test('preserva temporada e episódio no comando para uma série', () {
    const episode = TvCastPlaybackCommand(
      contentId: 'tmdb_123',
      pluginId: 'embedmovies',
      title: 'Série • S02E03',
      contentTitle: 'Série',
      posterUrl: '',
      mediaType: 'series',
      server: 'EmbedMovies',
      resumePositionMs: 0,
      season: 2,
      episode: 3,
    );

    final parsed = TvCastPlaybackCommand.tryParse(episode.toJson());

    expect(parsed, isNotNull);
    expect(parsed!.season, 2);
    expect(parsed.episode, 3);
    expect(Uri.parse(parsed.playerLocation).queryParameters['season'], '2');
    expect(Uri.parse(parsed.playerLocation).queryParameters['episode'], '3');
  });

  test('rejeita tipo desconhecido e posição inválida', () {
    final unknownType = command.toJson()..['mediaType'] = 'live';
    final negativePosition = command.toJson()..['resumePositionMs'] = -1;

    expect(TvCastPlaybackCommand.tryParse(unknownType), isNull);
    expect(TvCastPlaybackCommand.tryParse(negativePosition), isNull);
  });

  test('usa uma sala diferente para cada conta autenticada', () {
    expect(TvCastService.topicForUser('user-a'), 'ciney-cast:user-a');
    expect(
      TvCastService.topicForUser('user-a'),
      isNot(TvCastService.topicForUser('user-b')),
    );
  });
}
