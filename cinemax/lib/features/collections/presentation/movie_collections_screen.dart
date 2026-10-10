import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/gradient_poster.dart';
import '../../../plugin_engine/models/movie_collection.dart';
import '../../../plugin_engine/runtime/tmdb_service.dart';

class MovieCollectionsScreen extends StatefulWidget {
  const MovieCollectionsScreen({super.key});

  @override
  State<MovieCollectionsScreen> createState() => _MovieCollectionsScreenState();
}

class _MovieCollectionsScreenState extends State<MovieCollectionsScreen> {
  late Future<List<MovieCollection>> _collectionsFuture;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  void _loadCollections() {
    _collectionsFuture = TmdbService.getAvailableCollections();
  }

  void _openCollection(MovieCollection collection) {
    context.push(
      Uri(
        pathSegments: ['', 'collection', collection.id, collection.pluginId],
        queryParameters: {'name': collection.name},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Coleções', style: AppTypography.headlineMedium),
        backgroundColor: AppColors.background,
      ),
      body: FutureBuilder<List<MovieCollection>>(
        future: _collectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError || snapshot.data?.isEmpty != false) {
            return _buildFailure();
          }

          final collections = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              childAspectRatio: 0.66,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              return GradientPoster(
                title: collection.name,
                posterUrl: collection.posterUrl,
                onTap: () => _openCollection(collection),
              ).animate().fadeIn(duration: 180.ms);
            },
          );
        },
      ),
    );
  }

  Widget _buildFailure() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          Text(
            'Não foi possível carregar as coleções.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(_loadCollections),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
