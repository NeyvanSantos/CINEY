import 'package:dio/dio.dart';
import 'package:cinemax/core/config/app_environment.dart';
import 'package:cinemax/core/services/app_logger.dart';
import '../models/content_item.dart';
import '../models/movie_collection.dart';

/// Serviço que busca filmes, séries, animes e doramas do TMDB em tempo real
/// com fallback para o catálogo interno
class TmdbService {
  static const String _apiKey = '844dba0bfd8f3a4f3799f6130ef9e335';
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static String get _imageBaseUrl => AppEnvironment.isTv
      ? 'https://image.tmdb.org/t/p/w342'
      : 'https://image.tmdb.org/t/p/w500';
  static String get _backdropBaseUrl => AppEnvironment.isTv
      ? 'https://image.tmdb.org/t/p/w780'
      : 'https://image.tmdb.org/t/p/w1280';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      queryParameters: {'api_key': _apiKey, 'language': 'pt-BR'},
    ),
  );
  static const List<String> _availableCollectionIds = [
    '9485',
    '1241',
    '2150',
    '10194',
    '328',
    '295',
    '119',
    '2344',
    '8354',
    '131635',
    '263',
    '556',
    '748',
  ];
  static final Map<String, MovieCollection> _collectionCache = {};
  static final Map<String, Future<MovieCollection>> _collectionRequests = {};

  /// Converte JSON do TMDB para ContentItem
  static ContentItem? _mapJsonToItem(
    Map<String, dynamic> json,
    String pluginId, {
    ContentType? defaultType,
  }) {
    try {
      final mediaType = json['media_type']?.toString();
      if (mediaType == 'person') return null;

      final id = json['id']?.toString();
      final title =
          json['title'] ??
          json['name'] ??
          json['original_title'] ??
          json['original_name'];
      final posterPath = json['poster_path'];
      final backdropPath = json['backdrop_path'];

      if (id == null || title == null || title.toString().trim().isEmpty) {
        return null;
      }

      ContentType type;
      if (defaultType != null) {
        type = defaultType;
      } else if (mediaType == 'tv') {
        final originCountry =
            (json['origin_country'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        if (originCountry.contains('JP')) {
          type = ContentType.anime;
        } else if (originCountry.contains('KR')) {
          type = ContentType.dorama;
        } else {
          type = ContentType.series;
        }
      } else {
        type = ContentType.movie;
      }

      final dateStr = json['release_date'] ?? json['first_air_date'] ?? '';
      final year = dateStr.toString().split('-').first;
      final rating = (json['vote_average'] is num)
          ? (json['vote_average'] as num).toDouble()
          : null;

      final posterUrl = posterPath != null
          ? '$_imageBaseUrl$posterPath'
          : (backdropPath != null ? '$_imageBaseUrl$backdropPath' : '');

      return ContentItem(
        id: 'tmdb_${id}_${type.value}',
        title: title.toString(),
        posterUrl: posterUrl,
        backdropUrl: backdropPath != null
            ? '$_backdropBaseUrl$backdropPath'
            : (posterPath != null ? '$_backdropBaseUrl$posterPath' : null),
        year: year.isNotEmpty ? year : null,
        rating: rating != null && rating > 0
            ? double.parse(rating.toStringAsFixed(1))
            : null,
        type: type,
        pluginId: pluginId,
        overview: json['overview']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Busca filmes em alta na semana
  static Future<List<ContentItem>> getTrendingMovies({
    String pluginId = 'com.megaflix',
  }) async {
    try {
      final response = await _dio.get('/trending/movie/week');
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results
          .map(
            (j) => _mapJsonToItem(
              j as Map<String, dynamic>,
              pluginId,
              defaultType: ContentType.movie,
            ),
          )
          .whereType<ContentItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Busca séries em alta na semana
  static Future<List<ContentItem>> getTrendingSeries({
    String pluginId = 'com.supercine',
  }) async {
    try {
      final response = await _dio.get('/trending/tv/week');
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results
          .map(
            (j) => _mapJsonToItem(
              j as Map<String, dynamic>,
              pluginId,
              defaultType: ContentType.series,
            ),
          )
          .whereType<ContentItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Busca Animes populares
  static Future<List<ContentItem>> getPopularAnimes({
    String pluginId = 'com.animescloud',
  }) async {
    try {
      final response = await _dio.get(
        '/discover/tv',
        queryParameters: {
          'with_genres': '16', // Animação
          'with_original_language': 'ja', // Japonês
          'sort_by': 'popularity.desc',
        },
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results
          .map(
            (j) => _mapJsonToItem(
              j as Map<String, dynamic>,
              pluginId,
              defaultType: ContentType.anime,
            ),
          )
          .whereType<ContentItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Busca Doramas / K-Dramas populares
  static Future<List<ContentItem>> getPopularDoramas({
    String pluginId = 'com.doramas',
  }) async {
    try {
      final response = await _dio.get(
        '/discover/tv',
        queryParameters: {
          'with_original_language': 'ko', // Coreano
          'sort_by': 'popularity.desc',
        },
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results
          .map(
            (j) => _mapJsonToItem(
              j as Map<String, dynamic>,
              pluginId,
              defaultType: ContentType.dorama,
            ),
          )
          .whereType<ContentItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Busca filmes de Ação populares
  static Future<List<ContentItem>> getActionMovies({
    String pluginId = 'com.megaflix',
  }) async {
    try {
      final response = await _dio.get(
        '/discover/movie',
        queryParameters: {
          'with_genres': '28', // Ação
          'sort_by': 'popularity.desc',
        },
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results
          .map(
            (j) => _mapJsonToItem(
              j as Map<String, dynamic>,
              pluginId,
              defaultType: ContentType.movie,
            ),
          )
          .whereType<ContentItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Busca filmes de Ficção Científica populares
  static Future<List<ContentItem>> getSciFiMovies({
    String pluginId = 'com.megaflix',
  }) async {
    try {
      final response = await _dio.get(
        '/discover/movie',
        queryParameters: {
          'with_genres': '878', // Ficção Científica
          'sort_by': 'popularity.desc',
        },
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results
          .map(
            (j) => _mapJsonToItem(
              j as Map<String, dynamic>,
              pluginId,
              defaultType: ContentType.movie,
            ),
          )
          .whereType<ContentItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Busca filmes de Animação e Família
  static Future<List<ContentItem>> getAnimationMovies({
    String pluginId = 'com.amenictv',
  }) async {
    try {
      final response = await _dio.get(
        '/discover/movie',
        queryParameters: {
          'with_genres': '16,10751', // Animação + Família
          'sort_by': 'popularity.desc',
        },
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results
          .map(
            (j) => _mapJsonToItem(
              j as Map<String, dynamic>,
              pluginId,
              defaultType: ContentType.movie,
            ),
          )
          .whereType<ContentItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Busca títulos parametrizados no TMDB para o feed procedural infinito
  static Future<List<ContentItem>> getDiscoverContent({
    required String mediaType,
    String? withGenres,
    String? withOriginalLanguage,
    String? sortBy = 'popularity.desc',
    String? releaseDateLte,
    int? voteCountGte,
    int page = 1,
    String pluginId = 'com.megaflix',
    ContentType? defaultType,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'sort_by': sortBy ?? 'popularity.desc',
        'include_adult': 'false',
        'language': 'pt-BR',
      };
      if (withGenres != null && withGenres.isNotEmpty) {
        queryParams['with_genres'] = withGenres;
      }
      if (withOriginalLanguage != null && withOriginalLanguage.isNotEmpty) {
        queryParams['with_original_language'] = withOriginalLanguage;
      }
      if (releaseDateLte != null && releaseDateLte.isNotEmpty) {
        if (mediaType == 'movie') {
          queryParams['primary_release_date.lte'] = releaseDateLte;
        } else {
          queryParams['first_air_date.lte'] = releaseDateLte;
        }
      }
      if (voteCountGte != null && voteCountGte > 0) {
        queryParams['vote_count.gte'] = voteCountGte;
      }

      final response = await _dio.get(
        '/discover/$mediaType',
        queryParameters: queryParams,
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results
          .map(
            (j) => _mapJsonToItem(
              j as Map<String, dynamic>,
              pluginId,
              defaultType:
                  defaultType ??
                  (mediaType == 'tv' ? ContentType.series : ContentType.movie),
            ),
          )
          .whereType<ContentItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Realiza pesquisa geral no TMDB (Filmes, Séries, Animes, Doramas)
  static Future<List<ContentItem>> search(
    String query, {
    String pluginId = 'com.megaflix',
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      // 1. Busca Multi no TMDB com idioma pt-BR
      final response = await _dio.get(
        '/search/multi',
        queryParameters: {
          'query': cleanQuery,
          'include_adult': 'false',
          'language': 'pt-BR',
        },
      );
      final rawResults = response.data['results'] as List<dynamic>? ?? [];

      var items = rawResults
          .map((j) => _mapJsonToItem(j as Map<String, dynamic>, pluginId))
          .whereType<ContentItem>()
          .toList();

      // 2. Se a busca retornou vazia, tenta busca global/en-US
      if (items.isEmpty) {
        final fallbackResponse = await _dio.get(
          '/search/multi',
          queryParameters: {
            'query': cleanQuery,
            'include_adult': 'false',
            'language': 'en-US',
          },
        );
        final fallbackRaw =
            fallbackResponse.data['results'] as List<dynamic>? ?? [];
        items = fallbackRaw
            .map((j) => _mapJsonToItem(j as Map<String, dynamic>, pluginId))
            .whereType<ContentItem>()
            .toList();
      }

      // 3. Ordena por relevância: títulos que batem ou começam com o termo pesquisado têm prioridade
      final normalizedQuery = cleanQuery.toLowerCase();
      items.sort((a, b) {
        final aLower = a.title.toLowerCase();
        final bLower = b.title.toLowerCase();
        final aExact = aLower == normalizedQuery;
        final bExact = bLower == normalizedQuery;
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;

        final aStarts = aLower.startsWith(normalizedQuery);
        final bStarts = bLower.startsWith(normalizedQuery);
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;

        return 0;
      });

      return items;
    } catch (_) {
      return [];
    }
  }

  /// Busca os episódios de uma temporada de um título TV do TMDB.
  ///
  /// Os resultados de busca globais podem ter sido apresentados por qualquer
  /// plugin. Por isso, episódios de IDs `tmdb_*` precisam ser obtidos da fonte
  /// de metadados, em vez de depender da implementação daquele plugin.
  static Future<List<ContentItem>> getEpisodes(
    String contentId,
    int season, {
    required String pluginId,
    Dio? client,
  }) async {
    final parts = contentId.split('_');
    if (parts.length < 3 || season < 1) return const [];

    final tmdbId = int.tryParse(parts[1]);
    final type = parts[2];
    final isTv =
        type == 'series' || type == 'anime' || type == 'dorama' || type == 'tv';
    if (tmdbId == null || !isTv) return const [];

    try {
      final response = await (client ?? _dio).get('/tv/$tmdbId/season/$season');
      final data = response.data as Map<String, dynamic>;
      final rawEpisodes = data['episodes'] as List<dynamic>? ?? const [];
      final contentType = type == 'tv'
          ? ContentType.series
          : ContentType.fromString(type);

      final episodes =
          rawEpisodes
              .whereType<Map>()
              .map((rawEpisode) {
                final episode = Map<String, dynamic>.from(rawEpisode);
                final episodeNumber = _toPositiveInt(episode['episode_number']);
                if (episodeNumber == null) return null;

                final name = episode['name']?.toString().trim();
                final stillPath = episode['still_path']?.toString();
                final airDate = episode['air_date']?.toString() ?? '';
                final rating = episode['vote_average'];

                return ContentItem(
                  id: 'tmdb_episode_${tmdbId}_${season}_$episodeNumber',
                  title: name == null || name.isEmpty
                      ? 'Episódio $episodeNumber'
                      : 'Episódio $episodeNumber — $name',
                  posterUrl: stillPath != null && stillPath.isNotEmpty
                      ? '$_imageBaseUrl$stillPath'
                      : '',
                  backdropUrl: stillPath != null && stillPath.isNotEmpty
                      ? '$_backdropBaseUrl$stillPath'
                      : null,
                  year: airDate.isNotEmpty ? airDate.split('-').first : null,
                  rating: rating is num && rating > 0
                      ? double.parse(rating.toStringAsFixed(1))
                      : null,
                  type: contentType,
                  pluginId: pluginId,
                  overview: episode['overview']?.toString(),
                  episodeNumber: episodeNumber,
                );
              })
              .whereType<ContentItem>()
              .toList()
            ..sort(
              (a, b) => (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0),
            );

      return episodes;
    } catch (_) {
      return const [];
    }
  }

  static int? _toPositiveInt(dynamic value) {
    final number = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    return number != null && number > 0 ? number : null;
  }

  /// Busca detalhes completos e elenco de um título pelo ID do TMDB
  static Future<ContentDetail?> getDetail(
    String contentId,
    String pluginId, {
    Dio? client,
  }) async {
    if (!contentId.startsWith('tmdb_')) return null;

    try {
      // Extrai ID e Tipo se for formato tmdb_123_movie
      final parts = contentId.split('_');
      if (parts.length < 3) return null;

      final tmdbId = parts[1];
      final typeStr = parts[2];
      final isTv =
          typeStr == 'series' ||
          typeStr == 'anime' ||
          typeStr == 'dorama' ||
          typeStr == 'tv';

      final endpoint = isTv ? '/tv/$tmdbId' : '/movie/$tmdbId';
      final response = await (client ?? _dio).get(
        endpoint,
        queryParameters: {'append_to_response': 'credits,videos'},
      );

      final data = response.data as Map<String, dynamic>;
      final title =
          data['title'] ?? data['name'] ?? data['original_title'] ?? 'Título';
      final posterPath = data['poster_path'];
      final backdropPath = data['backdrop_path'];
      final overview = data['overview']?.toString();
      final rating = (data['vote_average'] is num)
          ? (data['vote_average'] as num).toDouble()
          : null;

      final dateStr = data['release_date'] ?? data['first_air_date'] ?? '';
      final year = dateStr.toString().split('-').first;

      final genresList =
          (data['genres'] as List<dynamic>?)
              ?.map((g) => g['name']?.toString() ?? '')
              .where((g) => g.isNotEmpty)
              .toList() ??
          [];

      final credits = data['credits'] as Map<String, dynamic>?;
      final castList =
          (credits?['cast'] as List<dynamic>?)
              ?.take(8)
              .map(
                (c) => CastMember(
                  name: c['name']?.toString() ?? '',
                  character: c['character']?.toString(),
                  photoUrl: c['profile_path'] != null
                      ? '$_imageBaseUrl${c['profile_path']}'
                      : null,
                ),
              )
              .toList() ??
          [];

      final runtime = isTv
          ? '${data['number_of_seasons'] ?? 1} Temporada(s)'
          : (data['runtime'] != null
                ? '${(data['runtime'] as int) ~/ 60}h ${(data['runtime'] as int) % 60}m'
                : '2h 10m');

      final seasonsList = isTv
          ? (data['seasons'] as List<dynamic>?)
                ?.map(
                  (s) => Season(
                    number: s['season_number'] as int? ?? 1,
                    name: s['name']?.toString(),
                    episodeCount: s['episode_count'] as int? ?? 10,
                  ),
                )
                .where((s) => s.number > 0)
                .toList()
          : null;
      final collection = data['belongs_to_collection'];
      final collectionId = !isTv && collection is Map<String, dynamic>
          ? collection['id']?.toString()
          : null;
      final collectionName = !isTv && collection is Map<String, dynamic>
          ? collection['name']?.toString()
          : null;

      return ContentDetail(
        id: contentId,
        title: title.toString(),
        posterUrl: posterPath != null ? '$_imageBaseUrl$posterPath' : '',
        backdropUrl: backdropPath != null
            ? '$_backdropBaseUrl$backdropPath'
            : null,
        overview: overview?.isNotEmpty == true
            ? overview
            : 'Uma produção espetacular com elenco premiado e história envolvente.',
        year: year.isNotEmpty ? year : null,
        duration: runtime,
        rating: rating != null && rating > 0
            ? double.parse(rating.toStringAsFixed(1))
            : null,
        type: ContentType.fromString(typeStr),
        pluginId: pluginId,
        genres: genresList,
        cast: castList,
        totalSeasons: isTv ? (data['number_of_seasons'] as int? ?? 1) : null,
        seasons: seasonsList,
        collectionId: collectionId,
        collectionName: collectionName,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<MovieCollection>> getAvailableCollections({
    String pluginId = 'com.megaflix',
    int? limit,
  }) async {
    final collectionIds = limit == null
        ? _availableCollectionIds
        : _availableCollectionIds.take(limit);
    final results = await Future.wait(
      collectionIds.map((id) async {
        try {
          return await getCollection(id, pluginId);
        } catch (_) {
          return null;
        }
      }),
    );
    final collections = results.whereType<MovieCollection>().toList();
    if (collections.isEmpty) {
      throw StateError('Não foi possível carregar as coleções.');
    }
    return collections;
  }

  static Future<MovieCollection> getCollection(
    String collectionId,
    String pluginId, {
    Dio? client,
  }) {
    final parsedId = int.tryParse(collectionId);
    if (parsedId == null || parsedId <= 0) {
      throw FormatException('ID de coleção TMDB inválido: $collectionId');
    }

    final cacheKey = '$pluginId:$parsedId';
    if (client != null) {
      return _loadCollection(parsedId, pluginId, client);
    }

    final cached = _collectionCache[cacheKey];
    if (cached != null) return Future.value(cached);
    final pending = _collectionRequests[cacheKey];
    if (pending != null) return pending;

    final request = _loadCollection(parsedId, pluginId, _dio)
        .then((collection) {
          _collectionCache[cacheKey] = collection;
          return collection;
        })
        .whenComplete(() => _collectionRequests.remove(cacheKey));
    _collectionRequests[cacheKey] = request;
    return request;
  }

  static Future<MovieCollection> _loadCollection(
    int collectionId,
    String pluginId,
    Dio client,
  ) async {
    try {
      final response = await client.get('/collection/$collectionId');
      final data = response.data as Map<String, dynamic>;
      final parts = (data['parts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .where((part) => part['id'] != null)
          .toList();
      parts.sort((first, second) {
        final firstDate = DateTime.tryParse(
          first['release_date']?.toString() ?? '',
        );
        final secondDate = DateTime.tryParse(
          second['release_date']?.toString() ?? '',
        );
        if (firstDate == null && secondDate != null) return 1;
        if (firstDate != null && secondDate == null) return -1;
        if (firstDate != null && secondDate != null) {
          final dateOrder = firstDate.compareTo(secondDate);
          if (dateOrder != 0) return dateOrder;
        }
        return first['id'].toString().compareTo(second['id'].toString());
      });

      final seenIds = <String>{};
      final movies = <ContentItem>[];
      for (final part in parts) {
        final mediaType = part['media_type']?.toString();
        if (mediaType != null && mediaType != 'movie') continue;
        final item = _mapJsonToItem(
          part,
          pluginId,
          defaultType: ContentType.movie,
        );
        if (item != null && seenIds.add(item.id)) movies.add(item);
      }

      final posterPath = data['poster_path']?.toString();
      final backdropPath = data['backdrop_path']?.toString();
      return MovieCollection(
        id: collectionId.toString(),
        name: data['name']?.toString() ?? 'Coleção de filmes',
        pluginId: pluginId,
        overview: data['overview']?.toString(),
        posterUrl: posterPath == null ? '' : '$_imageBaseUrl$posterPath',
        backdropUrl: backdropPath == null
            ? null
            : '$_backdropBaseUrl$backdropPath',
        movies: movies,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Falha ao carregar coleção TMDB $collectionId: $error',
        tag: 'TMDB',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
