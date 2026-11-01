import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/widgets/focusable_surface.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_poster.dart';
import '../../../core/services/app_logger.dart';
import '../../../plugin_engine/manager/plugin_manager.dart';
import '../../../plugin_engine/models/content_item.dart';
import '../../../plugin_engine/models/stream_source.dart';
import '../../../plugin_engine/runtime/stream_resolver.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../player/services/castlite_bridge_service.dart';
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
  int _sourceRequestId = 0;

  FocusNode? _watchButtonFocusNode;
  final Map<int, FocusNode> _seasonFocusNodes = {};
  final List<FocusNode> _episodeFocusNodes = [];

  FocusNode _getSeasonFocusNode(int season) {
    return _seasonFocusNodes.putIfAbsent(
      season,
      () => FocusNode(debugLabel: 'season_$season'),
    );
  }

  void _syncEpisodeFocusNodes(int count) {
    while (_episodeFocusNodes.length < count) {
      _episodeFocusNodes.add(
        FocusNode(debugLabel: 'episode_${_episodeFocusNodes.length}'),
      );
    }
    while (_episodeFocusNodes.length > count) {
      _episodeFocusNodes.removeLast().dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isTv) {
      _watchButtonFocusNode = FocusNode(
        debugLabel: 'watch_button',
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            final target = _seasonFocusNodes[_selectedSeason];
            if (target != null && target.canRequestFocus) {
              target.requestFocus();
              return KeyEventResult.handled;
            } else if (_episodeFocusNodes.isNotEmpty) {
              _episodeFocusNodes.first.requestFocus();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
      );
    }
    _detail = widget.initialDetail;
    _isLoading = _detail == null;
    _loadDetails();
  }

  @override
  void dispose() {
    _watchButtonFocusNode?.dispose();
    for (final node in _seasonFocusNodes.values) {
      node.dispose();
    }
    for (final node in _episodeFocusNodes) {
      node.dispose();
    }
    super.dispose();
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
        if (widget.isTv) {
          _syncEpisodeFocusNodes(episodes.length);
        }
        setState(() {
          _isLoadingEpisodes = false;
          _episodes = episodes;
        });
      }
    } catch (_) {
      if (mounted && requestId == _episodeRequestId) {
        if (widget.isTv) {
          _syncEpisodeFocusNodes(0);
        }
        setState(() => _isLoadingEpisodes = false);
      }
    }
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

  String _detailsRoute(ContentItem item) {
    final params = <String, String>{
      'title': item.title,
      'type': item.type.value,
      if (item.posterUrl.isNotEmpty) 'poster': item.posterUrl,
      if (item.overview?.isNotEmpty == true) 'overview': item.overview!,
    };
    return '/details/${item.id}/${item.pluginId}?${Uri(queryParameters: params).query}';
  }

  Future<void> _playContent({
    required ContentDetail item,
    int? season,
    int? episode,
    String? episodeTitle,
  }) async {
    final request = ++_sourceRequestId;
    final effectiveSeason = item.type == ContentType.movie
        ? null
        : (season ?? _selectedSeason);
    final effectiveEpisode = item.type == ContentType.movie
        ? null
        : (episode ?? 1);
    final titleText = episodeTitle != null && episodeTitle.isNotEmpty
        ? '${item.title} - $episodeTitle'
        : item.title;

    final sources = await _resolveSources(
      item,
      effectiveSeason,
      effectiveEpisode,
    );
    if (!mounted || request != _sourceRequestId) return;
    if (sources.isEmpty) {
      _sourcesUnavailable();
      return;
    }

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
      season: effectiveSeason,
      episode: effectiveEpisode,
      onSelect: navigateToPlayer,
    );
  }

  void _showServerSelectionSheet({
    required ContentDetail item,
    required List<StreamSource> sources,
    required int initialIndex,
    bool isCastMode = false,
    String? episodeText,
    int? season,
    int? episode,
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
        season: season,
        episode: episode,
        isTv: widget.isTv,
        isCastMode: isCastMode,
        initialIndex: initialIndex,
        onSelect: onSelect,
      ),
    );
  }

  Future<void> _onCastPressed(
    ContentDetail item, {
    int? episode,
    String? episodeTitle,
  }) async {
    if (widget.isTv) return;
    final request = ++_sourceRequestId;

    final effectiveSeason = item.type == ContentType.movie
        ? null
        : _selectedSeason;
    final effectiveEpisode = item.type == ContentType.movie
        ? null
        : (episode ??
              (_episodes.isNotEmpty ? _episodes.first.episodeNumber : null) ??
              1);

    final sources = await _resolveSources(
      item,
      effectiveSeason,
      effectiveEpisode,
    );
    if (!mounted || request != _sourceRequestId) return;

    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum servidor disponível para transmissão.'),
        ),
      );
      return;
    }

    void doCast(int serverIndex) {
      if (serverIndex < 0 || serverIndex >= sources.length) return;
      CastLiteBridgeService.launchCast(
        context: context,
        source: sources[serverIndex],
        sources: sources,
        title: episodeTitle == null
            ? item.title
            : '${item.title} - $episodeTitle',
        posterUrl: item.posterUrl,
        contentId: item.id,
        season: effectiveSeason,
        episode: effectiveEpisode,
      );
    }

    if (sources.length > 1) {
      _showServerSelectionSheet(
        item: item,
        sources: sources,
        initialIndex: 0,
        isCastMode: true,
        season: effectiveSeason,
        episode: effectiveEpisode,
        episodeText: effectiveSeason != null && effectiveEpisode != null
            ? 'T$effectiveSeason:E$effectiveEpisode'
            : null,
        onSelect: doCast,
      );
    } else {
      doCast(0);
    }
  }

  Future<List<StreamSource>> _resolveSources(
    ContentDetail item,
    int? season,
    int? episode,
  ) async {
    try {
      final sources = await ref
          .read(pluginManagerProvider.notifier)
          .getStreams(item.id, item.pluginId, season: season, episode: episode);
      return List<StreamSource>.of(sources)
        ..sort((a, b) => a.priority.compareTo(b.priority));
    } catch (error, stack) {
      AppLogger.error(
        'Falha ao consultar fontes (${error.runtimeType}).',
        tag: 'STREAM',
        stackTrace: stack,
      );
      return const [];
    }
  }

  void _sourcesUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível obter uma fonte de vídeo. Tente novamente.',
        ),
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
            expandedHeight: widget.isTv ? 180 : 300,
            pinned: true,
            backgroundColor: AppColors.background,
            actions: [
              FavoriteButton.fromDetail(detail: item),
              if (!widget.isTv)
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
                      // Decode to the physical display width instead of the
                      // original backdrop resolution on TV.
                      memCacheWidth: widget.isTv
                          ? (MediaQuery.sizeOf(context).width *
                                    MediaQuery.devicePixelRatioOf(context))
                                .ceil()
                          : null,
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
                          focusNode: _watchButtonFocusNode,
                          autofocus: widget.isTv,
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
                      FavoriteButton.fromDetail(detail: item),
                    ],
                  ),

                  if (!widget.isTv) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('details-cast-link'),
                        onPressed: () => _onCastPressed(item),
                        icon: const Icon(
                          Icons.cast_rounded,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          context.tr('detail.cast_button'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],

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
                      maxLines: widget.isTv ? 2 : null,
                      overflow: widget.isTv ? TextOverflow.ellipsis : null,
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
                    Text(
                      context.tr('detail.episodes'),
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    if (item.seasons != null && item.seasons!.isNotEmpty) ...[
                      SizedBox(
                        height: 42,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: item.seasons!.map((s) {
                              final isSelected = s.number == _selectedSeason;
                              final label = context
                                  .tr('detail.season')
                                  .replaceAll('{number}', '${s.number}');
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FocusableSurface(
                                  focusNode: widget.isTv
                                      ? _getSeasonFocusNode(s.number)
                                      : null,
                                  onKey: widget.isTv
                                      ? (node, event) {
                                          if (event is KeyDownEvent) {
                                            if (event.logicalKey ==
                                                LogicalKeyboardKey.arrowDown) {
                                              if (_episodeFocusNodes
                                                  .isNotEmpty) {
                                                _episodeFocusNodes.first
                                                    .requestFocus();
                                                return KeyEventResult.handled;
                                              }
                                            } else if (event.logicalKey ==
                                                LogicalKeyboardKey.arrowUp) {
                                              _watchButtonFocusNode
                                                  ?.requestFocus();
                                              return KeyEventResult.handled;
                                            }
                                          }
                                          return KeyEventResult.ignored;
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(21),
                                  onTap: () {
                                    if (!isSelected) {
                                      _loadEpisodes(s.number);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(21),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.glassBorder,
                                        width: 1.2,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
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
                      Column(
                        children: [
                          for (
                            var index = 0;
                            index < _episodes.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(height: 10),
                            () {
                              final ep = _episodes[index];
                              final episodeNumber =
                                  ep.episodeNumber ?? index + 1;
                              return GlassCard(
                                key: ValueKey(
                                  'episode-card-$_selectedSeason-$episodeNumber',
                                ),
                                focusNode:
                                    (widget.isTv &&
                                        index < _episodeFocusNodes.length)
                                    ? _episodeFocusNodes[index]
                                    : null,
                                onKey: widget.isTv
                                    ? (node, event) {
                                        if (event is KeyDownEvent) {
                                          if (event.logicalKey ==
                                              LogicalKeyboardKey.arrowUp) {
                                            if (index > 0 &&
                                                index - 1 <
                                                    _episodeFocusNodes.length) {
                                              _episodeFocusNodes[index - 1]
                                                  .requestFocus();
                                            } else {
                                              _getSeasonFocusNode(
                                                _selectedSeason,
                                              ).requestFocus();
                                            }
                                            return KeyEventResult.handled;
                                          } else if (event.logicalKey ==
                                              LogicalKeyboardKey.arrowDown) {
                                            if (index + 1 <
                                                _episodeFocusNodes.length) {
                                              _episodeFocusNodes[index + 1]
                                                  .requestFocus();
                                              return KeyEventResult.handled;
                                            }
                                          }
                                        }
                                        return KeyEventResult.ignored;
                                      }
                                    : null,
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
                                            ep.overview ??
                                                'Clique para reproduzir',
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
                                    if (!widget.isTv)
                                      IconButton(
                                        key: ValueKey(
                                          'cast-episode-$episodeNumber',
                                        ),
                                        tooltip:
                                            'Transmitir episódio $episodeNumber',
                                        icon: const Icon(
                                          Icons.cast_rounded,
                                          color: AppColors.primary,
                                        ),
                                        onPressed: () => _onCastPressed(
                                          item,
                                          episode: episodeNumber,
                                          episodeTitle: ep.title,
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
                            }(),
                          ],
                        ],
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 12.0;
                        const minWidthItem = 70.0;
                        final columns = math.max(
                          1,
                          ((constraints.maxWidth + spacing) / minWidthItem)
                              .floor(),
                        );
                        final cardWidth =
                            (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                        final photoSize = math.min(
                          88.0,
                          math.min(cardWidth * 0.75, cardWidth - 24),
                        );
                        final cacheWidth =
                            (photoSize * MediaQuery.devicePixelRatioOf(context))
                                .ceil();

                        return Wrap(
                          spacing: spacing,
                          runSpacing: 20,
                          children: [
                            for (final actor in item.cast)
                              SizedBox(
                                width: cardWidth,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipOval(
                                      child: SizedBox.square(
                                        dimension: photoSize,
                                        child:
                                            actor.photoUrl == null ||
                                                actor.photoUrl!.isEmpty
                                            ? const ColoredBox(
                                                color: AppColors.surfaceLight,
                                                child: Icon(
                                                  Icons.person,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: actor.photoUrl!,
                                                fit: BoxFit.contain,
                                                alignment: Alignment.center,
                                                memCacheWidth: cacheWidth,
                                                placeholder: (context, url) =>
                                                    const ColoredBox(
                                                      color: AppColors
                                                          .surfaceLight,
                                                    ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const ColoredBox(
                                                          color: AppColors
                                                              .surfaceLight,
                                                          child: Icon(
                                                            Icons.person,
                                                            color: AppColors
                                                                .textSecondary,
                                                          ),
                                                        ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      actor.name,
                                      style: AppTypography.labelMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                    if (actor.character?.isNotEmpty ??
                                        false) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        actor.character!,
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              color: AppColors.textTertiary,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],

                  // Títulos Semelhantes
                  if (item.similar.isNotEmpty) ...[
                    Text(
                      'Títulos Semelhantes',
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 195,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: item.similar.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final similar = item.similar[index];
                          return GradientPoster(
                            title: similar.title,
                            posterUrl: similar.posterUrl,
                            rating: similar.rating,
                            year: similar.year,
                            type: similar.type.value,
                            width: 130,
                            height: 195,
                            onTap: () => context.push(_detailsRoute(similar)),
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
