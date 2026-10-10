import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../plugin_engine/manager/plugin_manager.dart';
import '../../../plugin_engine/models/content_item.dart';
import '../../../plugin_engine/models/stream_source.dart';
import '../../../plugin_engine/runtime/stream_resolver.dart';
import '../../cast/presentation/cast_dialog.dart';
import '../../favorites/presentation/favorite_button.dart';
import 'widgets/server_selection_sheet.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  final String contentId;
  final String pluginId;
  final ContentDetail? initialDetail;
  final bool isTv;

  const DetailsScreen({
    super.key,
    required this.contentId,
    required this.pluginId,
    this.initialDetail,
    this.isTv = false,
  });

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  ContentDetail? _detail;
  bool _isLoading = true;
  int _selectedSeason = 1;
  List<ContentItem> _episodes = [];
  bool _isLoadingEpisodes = false;
  int _episodeRequestId = 0;

  @override
  void initState() {
    super.initState();
    _detail = widget.initialDetail;
    _isLoading = _detail == null;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (_detail == null) setState(() => _isLoading = true);
    _episodeRequestId++;
    final detail = await ref
        .read(pluginManagerProvider.notifier)
        .getDetail(widget.contentId, widget.pluginId);

    if (mounted) {
      setState(() {
        _detail = detail;
        _isLoading = false;
      });

      if (detail != null && detail.type != ContentType.movie) {
        final seasons = detail.seasons;
        final initialSeason = seasons != null && seasons.isNotEmpty
            ? seasons.first.number
            : 1;
        _loadEpisodes(initialSeason);
      }
    }
  }

  Future<void> _loadEpisodes(int season) async {
    final requestId = ++_episodeRequestId;
    setState(() {
      _selectedSeason = season;
      _isLoadingEpisodes = true;
      _episodes = [];
    });

    try {
      final episodes = await ref
          .read(pluginManagerProvider.notifier)
          .getEpisodes(widget.contentId, widget.pluginId, season);
      if (mounted && requestId == _episodeRequestId) {
        setState(() {
          _isLoadingEpisodes = false;
          _episodes = episodes;
        });
      }
    } catch (_) {
      if (mounted && requestId == _episodeRequestId) {
        setState(() => _isLoadingEpisodes = false);
      }
    }
  }

  void _showCast(ContentDetail item) {
    final sources = StreamResolverService.resolveFromContentId(
      item.id,
      season: item.type == ContentType.movie ? null : _selectedSeason,
      episode: item.type == ContentType.movie ? null : 1,
    );
    CastDialog.show(
      context,
      title: item.title,
      sources: sources,
      onOpenPlayer: () {
        if (!mounted) return;
        context.push(
          Uri(
            pathSegments: ['', 'player', item.id, item.pluginId],
            queryParameters: {
              'title': item.title,
              'contentTitle': item.title,
              'poster': item.posterUrl,
              'type': item.type.value,
              if (item.type != ContentType.movie) ...{
                'season': '$_selectedSeason',
                'episode': '1',
              },
            },
          ).toString(),
        );
      },
    );
  }

  void _openCollection(ContentDetail item) {
    final collectionId = item.collectionId;
    final collectionName = item.collectionName;
    if (collectionId == null || collectionName == null) return;
    context.push(
      Uri(
        pathSegments: ['', 'collection', collectionId, item.pluginId],
        queryParameters: {'name': collectionName},
      ).toString(),
    );
  }

  void _playContent({
    required ContentDetail item,
    int? season,
    int? episode,
    String? episodeTitle,
  }) {
    final effectiveSeason = item.type == ContentType.movie
        ? null
        : (season ?? _selectedSeason);
    final effectiveEpisode = item.type == ContentType.movie
        ? null
        : (episode ?? 1);
    final titleText = episodeTitle != null && episodeTitle.isNotEmpty
        ? '${item.title} - $episodeTitle'
        : item.title;

    final sources = StreamResolverService.resolveFromContentId(
      item.id,
      season: effectiveSeason,
      episode: effectiveEpisode,
    );

    void navigateToPlayer(int serverIndex) {
      if (!mounted) return;
      context.push(
        Uri(
          pathSegments: ['', 'player', item.id, item.pluginId],
          queryParameters: {
            'title': titleText,
            'contentTitle': item.title,
            'poster': item.posterUrl,
            'type': item.type.value,
            'serverIndex': '$serverIndex',
            if (effectiveSeason != null) 'season': '$effectiveSeason',
            if (effectiveEpisode != null) 'episode': '$effectiveEpisode',
          },
        ).toString(),
      );
    }

    if (sources.length <= 1) {
      navigateToPlayer(0);
      return;
    }

    final automaticIndex = StreamResolverService.automaticSourceIndex(sources);
    _showServerSelectionSheet(
      item: item,
      sources: sources,
      initialIndex: widget.isTv ? (automaticIndex ?? 0) : 0,
      episodeText: effectiveSeason != null && effectiveEpisode != null
          ? 'T$effectiveSeason:E$effectiveEpisode'
          : null,
      onSelect: navigateToPlayer,
    );
  }

  void _showServerSelectionSheet({
    required ContentDetail item,
    required List<StreamSource> sources,
    required int initialIndex,
    String? episodeText,
    required void Function(int serverIndex) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ServerSelectionSheet(
        item: item,
        sources: sources,
        episodeText: episodeText,
        isTv: widget.isTv,
        initialIndex: initialIndex,
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_detail == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(context.tr('detail.failed')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDetails,
                child: Text(context.tr('detail.retry')),
              ),
            ],
          ),
        ),
      );
    }

    final item = _detail!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Backdrop Header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.background,
            actions: [
              IconButton(
                icon: const Icon(Icons.cast_rounded, color: Colors.white),
                tooltip: 'Transmitir para TV',
                onPressed: () => _showCast(item),
              ),
              FavoriteButton.fromDetail(detail: item),
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                tooltip: 'Compartilhar',
                onPressed: () {},
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.backdropUrl != null)
                    CachedNetworkImage(
                      imageUrl: item.backdropUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          Container(color: AppColors.surface),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          AppColors.background.withValues(alpha: 0.8),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Informações do Título
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(item.title, style: AppTypography.displaySmall),
                  const SizedBox(height: 8),

                  // Metadados (Ano, Nota, Duração, Tipo)
                  Row(
                    children: [
                      if (item.rating != null) ...[
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.ratingGold,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.rating!.toStringAsFixed(1),
                          style: AppTypography.rating,
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (item.year != null) ...[
                        Text(
                          item.year!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (item.duration != null) ...[
                        Text(
                          item.duration!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          item.type.displayName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Botões de Ação Principal: Assistir e Download
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _playContent(item: item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          label: const Text(
                            'Assistir Agora',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () => _showCast(item),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primarySurface,
                          padding: const EdgeInsets.all(14),
                        ),
                        icon: const Icon(
                          Icons.cast_rounded,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Transmitir para Smart TV',
                      ),
                      const SizedBox(width: 8),
                      FavoriteButton.fromDetail(detail: item),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Tags de Gêneros
                  if (item.genres.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.genres
                          .map(
                            (g) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              child: Text(
                                g,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Sinopse
                  if (item.overview != null && item.overview!.isNotEmpty) ...[
                    Text(
                      context.tr('detail.synopsis'),
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.overview!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white70,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (item.type == ContentType.movie &&
                      item.collectionId != null &&
                      item.collectionName?.isNotEmpty == true) ...[
                    GlassCard(
                      onTap: () => _openCollection(item),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.movie_filter_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('detail.collection'),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.collectionName!,
                                  style: AppTypography.labelLarge,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Seletor de Temporadas e Lista de Episódios (Para Séries / Animes / Doramas)
                  if (item.type != ContentType.movie) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('detail.episodes'),
                          style: AppTypography.headlineMedium,
                        ),
                        if (item.seasons != null && item.seasons!.isNotEmpty)
                          DropdownButton<int>(
                            value: _selectedSeason,
                            dropdownColor: AppColors.surfaceLight,
                            items: item.seasons!
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s.number,
                                    child: Text(
                                      context
                                          .tr('detail.season')
                                          .replaceAll(
                                            '{number}',
                                            '${s.number}',
                                          ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) _loadEpisodes(val);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingEpisodes)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else if (_episodes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.playlist_remove_rounded,
                                color: AppColors.textTertiary,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr('detail.no_episodes'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 13,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _loadEpisodes(_selectedSeason),
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(context.tr('detail.retry')),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _episodes.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final ep = _episodes[index];
                          final episodeNumber = ep.episodeNumber ?? index + 1;
                          return GlassCard(
                            padding: const EdgeInsets.all(12),
                            onTap: () {
                              _playContent(
                                item: item,
                                season: _selectedSeason,
                                episode: episodeNumber,
                                episodeTitle: ep.title,
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ep.title,
                                        style: AppTypography.labelLarge,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        ep.overview ?? 'Clique para reproduzir',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textTertiary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],

                  // Elenco
                  if (item.cast.isNotEmpty) ...[
                    Text(
                      'Elenco Principal',
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: item.cast.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final actor = item.cast[index];
                          return Column(
                            children: [
                              SizedBox(
                                width: 60,
                                height: 60,
                                child: actor.photoUrl == null
                                    ? const CircleAvatar(
                                        radius: 30,
                                        backgroundColor: AppColors.surfaceLight,
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white70,
                                        ),
                                      )
                                    : ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: actor.photoUrl!,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 120,
                                          memCacheHeight: 120,
                                          placeholder: (context, url) =>
                                              Container(
                                                color: AppColors.surfaceLight,
                                              ),
                                          errorWidget: (context, url, error) =>
                                              const ColoredBox(
                                                color: AppColors.surfaceLight,
                                                child: Icon(
                                                  Icons.person,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  actor.name,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (actor.character != null)
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    actor.character!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textTertiary,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
