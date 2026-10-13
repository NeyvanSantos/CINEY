void main() {
  final uri = Uri(
    pathSegments: ['', 'player', 'tmdb_969681', 'embedmovies'],
    queryParameters: {'server': 'EmbedMovies'},
  );
  if (uri.path != '/player/tmdb_969681/embedmovies') {
    throw StateError('Rota inesperada: ${uri.path}');
  }
  if (uri.queryParameters['server'] != 'EmbedMovies') {
    throw StateError('Fonte ausente da rota: $uri');
  }
  print(uri);
}
