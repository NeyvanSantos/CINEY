/// Modelo de um item de conteúdo (filme, série, anime)
/// Retornado por plugins nas funções getHome() e search()
class ContentItem {
  final String id;
  final String title;
  final String posterUrl;
  final String? backdropUrl;
  final String? year;
  final double? rating;
  final ContentType type;
  final String pluginId;
  final String? overview;

  /// Número do episódio quando este item representa um episódio de série.
  ///
  /// Itens comuns do catálogo não precisam deste campo. Mantê-lo no modelo
  /// evita depender da posição visual da lista para abrir o episódio correto.
  final int? episodeNumber;

  const ContentItem({
    required this.id,
    required this.title,
    required this.posterUrl,
    this.backdropUrl,
    this.year,
    this.rating,
    required this.type,
    required this.pluginId,
    this.overview,
    this.episodeNumber,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json, String pluginId) {
    return ContentItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      posterUrl:
          json['poster']?.toString() ?? json['posterUrl']?.toString() ?? '',
      backdropUrl:
          json['backdrop']?.toString() ?? json['backdropUrl']?.toString(),
      year: json['year']?.toString(),
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : null,
      type: ContentType.fromString(json['type']?.toString() ?? 'movie'),
      pluginId: pluginId,
      overview: json['overview']?.toString(),
      episodeNumber: _parseInt(json['episodeNumber'] ?? json['episode_number']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'poster': posterUrl,
      'backdrop': backdropUrl,
      'year': year,
      'rating': rating,
      'type': type.value,
      'pluginId': pluginId,
      'overview': overview,
      'episodeNumber': episodeNumber,
    };
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

/// Detalhes completos de um título
/// Retornado pela função getDetail() do plugin
class ContentDetail {
  final String id;
  final String title;
  final String posterUrl;
  final String? backdropUrl;
  final String? overview;
  final String? year;
  final String? duration;
  final double? rating;
  final ContentType type;
  final String pluginId;
  final List<String> genres;
  final List<CastMember> cast;
  final String? trailerUrl;
  final int? totalSeasons;
  final List<Season>? seasons;

  const ContentDetail({
    required this.id,
    required this.title,
    required this.posterUrl,
    this.backdropUrl,
    this.overview,
    this.year,
    this.duration,
    this.rating,
    required this.type,
    required this.pluginId,
    this.genres = const [],
    this.cast = const [],
    this.trailerUrl,
    this.totalSeasons,
    this.seasons,
  });

  factory ContentDetail.fromJson(Map<String, dynamic> json, String pluginId) {
    return ContentDetail(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      posterUrl: json['poster']?.toString() ?? '',
      backdropUrl: json['backdrop']?.toString(),
      overview: json['overview']?.toString(),
      year: json['year']?.toString(),
      duration: json['duration']?.toString(),
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : null,
      type: ContentType.fromString(json['type']?.toString() ?? 'movie'),
      pluginId: pluginId,
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      cast:
          (json['cast'] as List<dynamic>?)
              ?.map((e) => CastMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      trailerUrl: json['trailerUrl']?.toString(),
      totalSeasons: json['totalSeasons'] as int?,
      seasons: (json['seasons'] as List<dynamic>?)
          ?.map((e) => Season.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Membro do elenco
class CastMember {
  final String name;
  final String? character;
  final String? photoUrl;

  const CastMember({required this.name, this.character, this.photoUrl});

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      name: json['name']?.toString() ?? '',
      character: json['character']?.toString(),
      photoUrl: json['photo']?.toString(),
    );
  }
}

/// Temporada de uma série
class Season {
  final int number;
  final String? name;
  final int? episodeCount;

  const Season({required this.number, this.name, this.episodeCount});

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      number: json['number'] as int? ?? 1,
      name: json['name']?.toString(),
      episodeCount: json['episodeCount'] as int?,
    );
  }
}

/// Tipo de conteúdo
enum ContentType {
  movie('movie'),
  series('series'),
  anime('anime'),
  dorama('dorama');

  final String value;
  const ContentType(this.value);

  static ContentType fromString(String value) {
    return ContentType.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => ContentType.movie,
    );
  }

  String get displayName {
    switch (this) {
      case ContentType.movie:
        return 'Filme';
      case ContentType.series:
        return 'Série';
      case ContentType.anime:
        return 'Anime';
      case ContentType.dorama:
        return 'Dorama';
    }
  }
}

/// Categoria de conteúdo na home
class ContentCategory {
  final String name;
  final List<ContentItem> items;

  const ContentCategory({required this.name, required this.items});

  factory ContentCategory.fromJson(Map<String, dynamic> json, String pluginId) {
    return ContentCategory(
      name: json['name']?.toString() ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (e) =>
                    ContentItem.fromJson(e as Map<String, dynamic>, pluginId),
              )
              .toList() ??
          [],
    );
  }
}
