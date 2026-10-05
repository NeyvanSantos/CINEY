import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/app_logger.dart';
import '../contracts/plugin_interface.dart';
import '../models/content_item.dart';
import '../models/stream_source.dart';
import '../plugins/builtin_plugins.dart';
import '../runtime/stream_resolver.dart';
import '../runtime/tmdb_service.dart';

/// Estado do Gerenciador de Plugins
class PluginState {
  final List<PluginInterface> installedPlugins;
  final PluginInterface? activePlugin;
  final bool isLoading;

  const PluginState({
    this.installedPlugins = const [],
    this.activePlugin,
    this.isLoading = false,
  });

  PluginState copyWith({
    List<PluginInterface>? installedPlugins,
    PluginInterface? activePlugin,
    bool? isLoading,
  }) {
    return PluginState(
      installedPlugins: installedPlugins ?? this.installedPlugins,
      activePlugin: activePlugin ?? this.activePlugin,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Provider do PluginManager
final pluginManagerProvider = StateNotifierProvider<PluginManager, PluginState>(
  (ref) {
    return PluginManager();
  },
);

class PluginManager extends StateNotifier<PluginState> {
  PluginManager() : super(const PluginState()) {
    _initializeDefaultPlugins();
  }

  List<ContentCategory>? _homeCache;
  DateTime? _homeCacheAt;
  Future<List<ContentCategory>>? _homeRequest;
  final Map<String, ContentDetail> _detailCache = {};
  final Map<String, Future<ContentDetail?>> _detailRequests = {};

  void _invalidateHomeCache() {
    _homeCache = null;
    _homeCacheAt = null;
  }

  /// Lista de todos os plugins disponíveis no ecossistema
  static List<PluginInterface> get allAvailablePlugins => [
    PublicDomainPlugin(),
    MegaFlixPlugin(),
    SuperCinePlugin(),
    AnimesCloudPlugin(),
    DoramasPlugin(),
    AmenicTVPlugin(),
    ProbreFlixPlugin(),
    StreamberryPlugin(),
  ];

  /// Inicializa os plugins padrão
  void _initializeDefaultPlugins() {
    final defaultList = allAvailablePlugins;
    state = state.copyWith(
      installedPlugins: defaultList,
      activePlugin: defaultList.first,
      isLoading: false,
    );
  }

  /// Busca um item estático em todas as listas internas pelo ID
  static ContentItem? findInternalItemById(String id) {
    final all = [
      ...MegaFlixPlugin.movies,
      ...SuperCinePlugin.seriesList,
      ...AnimesCloudPlugin.animesList,
      ...DoramasPlugin.doramasList,
      ...AmenicTVPlugin.animationsList,
      ...ProbreFlixPlugin.probreList,
      ...StreamberryPlugin.horrorList,
      ...PublicDomainPlugin.movies,
    ];
    final matches = all.where((i) => i.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Define a lista de plugins instalados a partir de uma lista de IDs selecionados
  void setInstalledPluginIds(List<String> selectedIds) {
    final list = allAvailablePlugins
        .where((p) => selectedIds.contains(p.manifest.id))
        .toList();
    final finalList = list.isNotEmpty ? list : allAvailablePlugins;
    state = state.copyWith(
      installedPlugins: finalList,
      activePlugin: finalList.first,
    );
    _invalidateHomeCache();
  }

  /// Instala todas as extensões disponíveis
  void installAllPlugins() {
    state = state.copyWith(
      installedPlugins: allAvailablePlugins,
      activePlugin: allAvailablePlugins.first,
    );
    _invalidateHomeCache();
  }

  /// Define o plugin ativo atual
  void setActivePlugin(PluginInterface plugin) {
    state = state.copyWith(activePlugin: plugin);
  }

  /// Define o plugin ativo por ID
  void setActivePluginById(String id) {
    final found = state.installedPlugins.firstWhere(
      (p) => p.manifest.id == id,
      orElse: () => state.installedPlugins.first,
    );
    state = state.copyWith(activePlugin: found);
  }

  /// Remove/Desinstala um plugin
  void removePlugin(String pluginId) {
    final updated = state.installedPlugins
        .where((p) => p.manifest.id != pluginId)
        .toList();
    final newActive = state.activePlugin?.manifest.id == pluginId
        ? (updated.isNotEmpty ? updated.first : null)
        : state.activePlugin;

    state = state.copyWith(installedPlugins: updated, activePlugin: newActive);
    _invalidateHomeCache();
  }

  /// Instala um novo plugin
  void installPlugin(PluginInterface plugin) {
    if (state.installedPlugins.any(
      (p) => p.manifest.id == plugin.manifest.id,
    )) {
      return; // Já instalado
    }
    final updated = [...state.installedPlugins, plugin];
    state = state.copyWith(installedPlugins: updated);
    _invalidateHomeCache();
  }

  /// Busca em todos os plugins instalados e no TMDB simultaneamente
  Future<List<ContentItem>> searchAll(String query) async {
    if (query.trim().isEmpty) return [];

    AppLogger.info('Iniciando busca: "$query"', tag: 'SEARCH');

    final results = <ContentItem>[];
    final seenTitles = <String>{};

    final liveResultsFuture = TmdbService.search(query).catchError((error) {
      AppLogger.error('Erro na busca TMDB: $error', tag: 'SEARCH');
      return <ContentItem>[];
    });
    final pluginResultsFuture = Future.wait(
      state.installedPlugins.map((plugin) async {
        try {
          final items = await plugin.search(query);
          if (items.isNotEmpty) {
            AppLogger.debug(
              'Plugin "${plugin.manifest.id}" encontrou ${items.length} item(s)',
              tag: 'PLUGIN',
            );
          }
          return items;
        } catch (error) {
          AppLogger.warn(
            'Plugin "${plugin.manifest.id}" falhou na busca: $error',
            tag: 'PLUGIN',
          );
          return <ContentItem>[];
        }
      }),
    );

    final liveResults = await liveResultsFuture;
    for (final item in liveResults) {
      final key = item.title.toLowerCase().trim();
      if (seenTitles.add(key)) results.add(item);
    }
    AppLogger.success(
      'TMDB retornou ${liveResults.length} resultado(s) para "$query"',
      tag: 'SEARCH',
    );
    for (final items in await pluginResultsFuture) {
      for (final item in items) {
        final key = item.title.toLowerCase().trim();
        if (seenTitles.add(key)) results.add(item);
      }
    }

    AppLogger.info(
      'Busca concluída: ${results.length} título(s) no total para "$query"',
      tag: 'SEARCH',
    );
    return results;
  }

  /// Retorna as seções UNIFICADAS de TODAS as bibliotecas/plugins juntos
  Future<List<ContentCategory>> getAllHomeSections() async {
    final cached = _homeCache;
    final cacheAge = _homeCacheAt == null
        ? null
        : DateTime.now().difference(_homeCacheAt!);
    if (cached != null &&
        cacheAge != null &&
        cacheAge < const Duration(minutes: 2)) {
      return cached;
    }
    final inFlight = _homeRequest;
    if (inFlight != null) return inFlight;

    final request = _loadHomeSections();
    _homeRequest = request;
    try {
      final sections = await request;
      _homeCache = sections;
      _homeCacheAt = DateTime.now();
      return sections;
    } finally {
      if (identical(_homeRequest, request)) _homeRequest = null;
    }
  }

  Future<List<ContentCategory>> _loadHomeSections() async {
    final sections = <ContentCategory>[];
    final seenTitles = <String>{};

    final pluginSections = await Future.wait(
      state.installedPlugins.map((plugin) async {
        try {
          return await plugin.getHome();
        } catch (_) {
          return <ContentCategory>[];
        }
      }),
    );
    for (final pluginResult in pluginSections) {
      for (final section in pluginResult) {
        final cleanItems = <ContentItem>[];
        for (final item in section.items) {
          final key = item.title.toLowerCase().trim();
          if (seenTitles.add(key)) {
            cleanItems.add(item);
          }
        }
        if (cleanItems.isNotEmpty) {
          sections.add(ContentCategory(name: section.name, items: cleanItems));
        }
      }
    }
    return sections;
  }

  /// Retorna as seções da Home (padrão agregada de todas as bibliotecas)
  Future<List<ContentCategory>> getHomeSections() async {
    return getAllHomeSections();
  }

  /// Retorna detalhes do título buscando com exatidão pelo ID
  Future<ContentDetail?> getDetail(String contentId, String pluginId) async {
    final cacheKey = '$contentId:$pluginId';
    final cached = _detailCache[cacheKey];
    if (cached != null) return cached;
    final pending = _detailRequests[cacheKey];
    if (pending != null) return pending;

    final request = _loadDetail(contentId, pluginId);
    _detailRequests[cacheKey] = request;
    try {
      final detail = await request;
      if (detail != null) _detailCache[cacheKey] = detail;
      return detail;
    } finally {
      _detailRequests.remove(cacheKey);
    }
  }

  Future<ContentDetail?> _loadDetail(String contentId, String pluginId) async {
    // 1. Se for ID do TMDB
    if (contentId.startsWith('tmdb_')) {
      final liveDetail = await TmdbService.getDetail(contentId, pluginId);
      if (liveDetail != null) return liveDetail;
    }

    // 2. Busca nos itens internos
    final internal = findInternalItemById(contentId);
    if (internal != null) {
      final isSeries =
          internal.type == ContentType.series ||
          internal.type == ContentType.anime ||
          internal.type == ContentType.dorama;
      final localDetail = ContentDetail(
        id: internal.id,
        title: internal.title,
        posterUrl: internal.posterUrl,
        backdropUrl: internal.backdropUrl,
        overview: internal.overview,
        year: internal.year ?? '2024',
        duration: isSeries ? 'Temporadas Completas' : '2h 15m',
        rating: internal.rating ?? 8.5,
        type: internal.type,
        pluginId: pluginId.isNotEmpty ? pluginId : internal.pluginId,
        genres: [internal.type.displayName, 'Ação', 'Drama'],
        totalSeasons: isSeries ? 4 : null,
        seasons: isSeries
            ? const [
                Season(number: 1, name: 'Temporada 1', episodeCount: 8),
                Season(number: 2, name: 'Temporada 2', episodeCount: 8),
              ]
            : null,
      );
      if (localDetail.posterUrl.isNotEmpty &&
          localDetail.overview?.isNotEmpty == true) {
        return localDetail;
      }

      try {
        final matches = await TmdbService.search(internal.title);
        final match = matches.cast<ContentItem?>().firstWhere(
          (item) =>
              item != null &&
              (internal.year == null || item.year == internal.year),
          orElse: () => matches.isEmpty ? null : matches.first,
        );
        if (match != null) {
          return ContentDetail(
            id: internal.id,
            title: localDetail.title,
            posterUrl: localDetail.posterUrl.isNotEmpty
                ? localDetail.posterUrl
                : match.posterUrl,
            backdropUrl: localDetail.backdropUrl ?? match.backdropUrl,
            overview: localDetail.overview?.isNotEmpty == true
                ? localDetail.overview
                : match.overview,
            year: localDetail.year ?? match.year,
            duration: localDetail.duration,
            rating: localDetail.rating ?? match.rating,
            type: localDetail.type,
            pluginId: localDetail.pluginId,
            genres: localDetail.genres,
            totalSeasons: localDetail.totalSeasons,
            seasons: localDetail.seasons,
          );
        }
      } catch (_) {}
      return localDetail;
    }

    // 3. Busca no plugin alvo
    final target = state.installedPlugins.firstWhere(
      (p) => p.manifest.id == pluginId,
      orElse: () => state.activePlugin ?? state.installedPlugins.first,
    );
    try {
      final detail = await target.getDetail(contentId);
      return detail;
    } catch (_) {
      return null;
    }
  }

  /// Retorna episódios, priorizando o TMDB para conteúdos identificados por
  /// `tmdb_*`. O plugin que exibiu o resultado pode não implementar episódios.
  Future<List<ContentItem>> getEpisodes(
    String contentId,
    String pluginId,
    int season,
  ) async {
    if (contentId.startsWith('tmdb_')) {
      final liveEpisodes = await TmdbService.getEpisodes(
        contentId,
        season,
        pluginId: pluginId,
      );
      if (liveEpisodes.isNotEmpty) {
        AppLogger.success(
          '${liveEpisodes.length} episódio(s) carregado(s) do TMDB para $contentId, temporada $season.',
          tag: 'EPISODES',
        );
        return liveEpisodes;
      }
    }

    PluginInterface? target;
    for (final plugin in state.installedPlugins) {
      if (plugin.manifest.id == pluginId) {
        target = plugin;
        break;
      }
    }
    target ??= state.activePlugin;
    if (target == null) return const [];

    try {
      return await target.getEpisodes(contentId, season);
    } catch (error, stack) {
      AppLogger.error(
        'Falha ao carregar episódios de $contentId, temporada $season: $error',
        tag: 'EPISODES',
        stackTrace: stack,
      );
      return const [];
    }
  }

  /// Usa exclusivamente EmbedMovies. IDs locais mapeados são resolvidos
  /// diretamente; os demais títulos conhecidos são identificados via TMDB.
  Future<List<StreamSource>> getStreams(
    String contentId,
    String pluginId, {
    int? season,
    int? episode,
  }) async {
    AppLogger.info(
      'Solicitando fontes para $contentId, plugin $pluginId.',
      tag: 'STREAM',
    );
    final sources = StreamResolverService.resolveFromContentId(
      contentId,
      season: season,
      episode: episode,
    );
    if (sources.isNotEmpty) {
      AppLogger.info(
        'Fonte selecionada: EmbedMovies para $contentId.',
        tag: 'STREAM',
      );
      return sources;
    }
    // Títulos locais sem mapeamento também usam apenas EmbedMovies.
    final internalItem = findInternalItemById(contentId);
    if (internalItem != null) {
      try {
        final searchResults = await TmdbService.search(internalItem.title);
        if (searchResults.isNotEmpty) {
          final normalizedTitle = internalItem.title.toLowerCase().trim();
          final rankedResults = [...searchResults]
            ..sort((a, b) {
              int score(ContentItem item) {
                var value = 0;
                if (item.title.toLowerCase().trim() == normalizedTitle) {
                  value += 4;
                }
                if (item.type == internalItem.type) value += 2;
                if (internalItem.year != null &&
                    item.year == internalItem.year) {
                  value += 1;
                }
                return value;
              }

              return score(b).compareTo(score(a));
            });
          final tmdbContentId = rankedResults.first.id;
          final sources = StreamResolverService.resolveFromContentId(
            tmdbContentId,
            season: season,
            episode: episode,
          );
          if (sources.isNotEmpty) {
            AppLogger.success(
              '${sources.length} fonte(s) resolvida(s) via TMDB para $contentId.',
              tag: 'STREAM',
            );
            return sources;
          }
        }
      } catch (error, stack) {
        AppLogger.error(
          'Falha ao resolver $contentId via TMDB: $error',
          tag: 'STREAM',
          stackTrace: stack,
        );
      }
    }

    AppLogger.warn(
      'Não foi possível identificar $contentId no EmbedMovies.',
      tag: 'STREAM',
    );
    return const [];
  }
}
