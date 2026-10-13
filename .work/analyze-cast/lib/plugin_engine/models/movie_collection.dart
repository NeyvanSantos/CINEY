import 'content_item.dart';

class MovieCollection {
  final String id;
  final String name;
  final String pluginId;
  final String? overview;
  final String posterUrl;
  final String? backdropUrl;
  final List<ContentItem> movies;

  const MovieCollection({
    required this.id,
    required this.name,
    required this.pluginId,
    this.overview,
    required this.posterUrl,
    this.backdropUrl,
    this.movies = const [],
  });
}
