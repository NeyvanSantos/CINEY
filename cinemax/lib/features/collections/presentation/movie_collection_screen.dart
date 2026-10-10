import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../plugin_engine/models/content_item.dart';
import '../../../plugin_engine/models/movie_collection.dart';
import '../../../plugin_engine/runtime/tmdb_service.dart';

class MovieCollectionScreen extends StatefulWidget {
  final String collectionId;
  final String pluginId;
  final String collectionName;
  final Future<MovieCollection> Function(String, String)? loadCollection;

  const MovieCollectionScreen({
    super.key,
    required this.collectionId,
    required this.pluginId,
    required this.collectionName,
    this.loadCollection,
  });

  @override
  State<MovieCollectionScreen> createState() => _MovieCollectionScreenState();
}

class _MovieCollectionScreenState extends State<MovieCollectionScreen> {
  late Future<MovieCollection> _collectionFuture;

  @override
  void initState() {
    super.initState();
    _loadCollection();
  }

  void _loadCollection() {
    _collectionFuture = (widget.loadCollection ?? TmdbService.getCollection)(
      widget.collectionId,
      widget.pluginId,
    );
  }

  void _retry() => setState(_loadCollection);

  void _openMovie(ContentItem movie) {
    context.push(
      Uri(
        pathSegments: ['', 'details', movie.id, movie.pluginId],
        queryParameters: {
          'title': movie.title,
          'type': movie.type.value,
          if (movie.posterUrl.isNotEmpty) 'poster': movie.posterUrl,
          if (movie.overview?.isNotEmpty == true) 'overview': movie.overview!,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.collectionName,
          style: AppTypography.headlineMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.background,
      ),
      body: FutureBuilder<MovieCollection>(
        future: _collectionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError) return _buildFailure();

          final collection = snapshot.data;
          if (collection == null || collection.movies.isEmpty) {
            return _buildEmpty();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(collection.name, style: AppTypography.headlineLarge),
              const SizedBox(height: 6),
              Text(
                '${collection.movies.length} filmes • ordem de lançamento',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (collection.overview?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  collection.overview!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              for (var index = 0; index < collection.movies.length; index++)
                _buildMovieCard(collection.movies[index], index),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMovieCard(ContentItem movie, int index) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      onTap: () => _openMovie(movie),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '${index + 1}',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 64,
              height: 96,
              child: movie.posterUrl.isEmpty
                  ? _posterFallback()
                  : CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => _posterFallback(),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  style: AppTypography.labelLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (movie.year?.isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(
                    movie.year!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _posterFallback() => Container(
    color: AppColors.surfaceLight,
    alignment: Alignment.center,
    child: const Icon(Icons.movie_rounded, color: AppColors.textTertiary),
  );

  Widget _buildFailure() => _buildMessage(
    icon: Icons.cloud_off_rounded,
    message: 'Não foi possível carregar esta coleção.',
    action: TextButton.icon(
      onPressed: _retry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Tentar novamente'),
    ),
  );

  Widget _buildEmpty() => _buildMessage(
    icon: Icons.movie_filter_rounded,
    message: 'Nenhum filme disponível nesta coleção.',
  );

  Widget _buildMessage({
    required IconData icon,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textTertiary, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
