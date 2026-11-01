import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    bool clearActivePlugin = false,
    bool? isLoading,
  }) {
    return PluginState(
      installedPlugins: installedPlugins ?? this.installedPlugins,
      activePlugin: clearActivePlugin
          ? null
          : activePlugin ?? this.activePlugin,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Provider do PluginManager
final pluginManagerProvider = StateNotifierProvider<PluginManager, PluginState>(
  (ref) {
    return PluginManager(preferencesLoader: SharedPreferences.getInstance);
  },
);

class PluginManager extends StateNotifier<PluginState> {
  PluginManager({
    Future<SharedPreferences> Function()? preferencesLoader,
    Dio? catalogClient,
  }) : _preferencesLoader = preferencesLoader,
       _catalogClient = catalogClient,
       super(const PluginState()) {
    _initializeDefaultPlugins();
    ready = preferencesLoader == null
        ? Future.value()
        : _restoreConfiguration();
  }

  final Future<SharedPreferences> Function()? _preferencesLoader;
  final Dio? _catalogClient;
  late final Future<void> ready;
  Future<void> _configurationWrites = Future.value();
  int _configurationGeneration = 0;
  static const _installedKey = 'installed-plugins-v1';
  static const _activeKey = 'active-plugin-v1';

  Future<void> _restoreConfiguration() async {
    final generation = _configurationGeneration;
    try {
      final preferences = await _preferencesLoader!();
      if (!mounted || generation != _configurationGeneration) return;
      final ids = preferences.getStringList(_installedKey);
      if (ids == null) return;
      final plugins = allAvailablePlugins
          .where((p) => ids.contains(p.manifest.id))
          .toList();
      final activeId = preferences.getString(_activeKey);
      final active =
          plugins.where((p) => p.manifest.id == activeId).firstOrNull ??
          plugins.firstOrNull;
      state = state.copyWith(
        installedPlugins: plugins,
        activePlugin: active,
        clearActivePlugin: active == null,
      );
      _invalidateHomeCache();
    } catch (error) {
      AppLogger.warn(
        'Falha ao restaurar extensões (${error.runtimeType}).',
        tag: 'PLUGIN',
      );
    }
  }

  void _saveConfiguration() {
    _configurationGeneration++;
    if (_preferencesLoader == null) return;
    final ids = state.installedPlugins.map((p) => p.manifest.id).toList();
    final activeId = state.activePlugin?.manifest.id;
    _configurationWrites = _configurationWrites
        .then((_) async {
          await ready;
          final preferences = await _preferencesLoader();
          await preferences.setStringList(_installedKey, ids);
          if (activeId == null) {
            await preferences.remove(_activeKey);
          } else {
            await preferences.setString(_activeKey, activeId);
          }
        })
        .catchError((Object error) {
          AppLogger.warn(
            'Falha ao salvar extensões (${error.runtimeType}).',
            tag: 'PLUGIN',
          );
        });
  }

  Future<void> flushConfiguration() => _configurationWrites;

  List<ContentCategory>? _homeCache;
  DateTime? _homeCacheAt;
  Future<List<ContentCategory>>? _homeRequest;
  final Map<String, ContentDetail> _detailCache = {};
  final Map<String, Future<ContentDetail?>> _detailRequests = {};
  final Map<String, String> _resolvedCatalogIds = {};

  void _invalidateHomeCache() {
    _homeCache = null;
    _homeCacheAt = null;
    _homeRequest = null;
    _detailCache.clear();
    _detailRequests.clear();
    _resolvedCatalogIds.clear();
    _catalogGeneration++;
  }

  int _catalogGeneration = 0;

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
    state = state.copyWith(
      installedPlugins: list,
      activePlugin: list.firstOrNull,
      clearActivePlugin: list.isEmpty,
    );
    _invalidateHomeCache();
    _saveConfiguration();
  }

  /// Instala todas as extensões disponíveis
  void installAllPlugins() {
    state = state.copyWith(
      installedPlugins: allAvailablePlugins,
      activePlugin: allAvailablePlugins.first,
    );
    _invalidateHomeCache();
    _saveConfiguration();
  }

  /// Define o plugin ativo atual
  void setActivePlugin(PluginInterface plugin) {
    if (!state.installedPlugins.contains(plugin)) return;
    state = state.copyWith(activePlugin: plugin);
    _saveConfiguration();
  }

  /// Define o plugin ativo por ID
  void setActivePluginById(String id) {
    if (state.installedPlugins.isEmpty) return;
    final found = state.installedPlugins.firstWhere(
      (p) => p.manifest.id == id,
      orElse: () => state.installedPlugins.first,
    );
    state = state.copyWith(activePlugin: found);
    _saveConfiguration();
  }

  /// Remove/Desinstala um plugin
  void removePlugin(String pluginId) {
    final updated = state.installedPlugins
        .where((p) => p.manifest.id != pluginId)
        .toList();
    final newActive = state.activePlugin?.manifest.id == pluginId
        ? (updated.isNotEmpty ? updated.first : null)
        : state.activePlugin;

    state = state.copyWith(
      installedPlugins: updated,
      activePlugin: newActive,
      clearActivePlugin: newActive == null,
    );
    _invalidateHomeCache();
    _saveConfiguration();
  }

  /// Instala um novo plugin
  void installPlugin(PluginInterface plugin) {
    if (state.installedPlugins.any(
      (p) => p.manifest.id == plugin.manifest.id,
    )) {
      return; // Já instalado
    }
    final updated = [...state.installedPlugins, plugin];
    state = state.copyWith(
      installedPlugins: updated,
      activePlugin: state.activePlugin ?? plugin,
    );
    _invalidateHomeCache();
    _saveConfiguration();
  }

  /// Busca em todos os plugins instalados e no TMDB simultaneamente
  Future<List<ContentItem>> searchAll(String query) async {
    await ready;
    if (query.trim().isEmpty) return [];

    AppLogger.info('Iniciando busca: "$query"', tag: 'SEARCH');

    final results = <ContentItem>[];
    final seenTitles = <String>{};

    var catalogFailed = false;
    final liveResultsFuture = TmdbService.search(query, client: _catalogClient)
        .catchError((error) {
          catalogFailed = true;
          AppLogger.error(
            'Erro na busca TMDB (${error.runtimeType}).',
            tag: 'SEARCH',
          );
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
      final key = _searchContentKey(item);
      if (seenTitles.add(key)) results.add(item);
    }
    if (!catalogFailed) {
      AppLogger.success(
        'TMDB retornou ${liveResults.length} resultado(s) para "$query"',
        tag: 'SEARCH',
      );
    }
    for (final items in await pluginResultsFuture) {
      for (final item in items) {
        final key = _searchContentKey(item);
        if (seenTitles.add(key)) results.add(item);
      }
    }

    if (catalogFailed && results.isEmpty) {
      throw StateError('Não foi possível consultar o catálogo.');
    }
    AppLogger.info(
      'Busca concluída: ${results.length} título(s) no total para "$query"',
      tag: 'SEARCH',
    );
    return results;
  }

  /// Retorna as seções UNIFICADAS de TODAS as bibliotecas/plugins juntos
  Future<List<ContentCategory>> getAllHomeSections() async {
    await ready;
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
      if (identical(_homeRequest, request)) {
        _homeCache = sections;
        _homeCacheAt = DateTime.now();
      }
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
        } catch (error, stack) {
          AppLogger.error(
            'Falha no catálogo ${plugin.manifest.id} (${error.runtimeType}).',
            tag: 'PLUGIN',
            stackTrace: stack,
          );
          return <ContentCategory>[];
        }
      }),
    );
    for (final pluginResult in pluginSections) {
      for (final section in pluginResult) {
        final cleanItems = <ContentItem>[];
        for (final item in section.items) {
          final key = _contentKey(item);
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
    await ready;
    final generation = _catalogGeneration;
    final cacheKey = '$contentId:$pluginId';
    final cached = _detailCache[cacheKey];
    if (cached != null) return cached;
    final pending = _detailRequests[cacheKey];
    if (pending != null) return pending;

    final request = _loadDetail(contentId, pluginId);
    _detailRequests[cacheKey] = request;
    try {
      final detail = await request;
      if (generation != _catalogGeneration) return null;
      if (detail != null) {
        if (detail.id != contentId &&
            StreamResolverService.catalogIdFor(detail.id) !=
                (_resolvedCatalogIds[contentId] ??
                    StreamResolverService.catalogIdFor(contentId))) {
          return null;
        }
        _detailCache[cacheKey] = detail;
      }
      return detail;
    } finally {
      if (identical(_detailRequests[cacheKey], request)) {
        _detailRequests.remove(cacheKey);
      }
    }
  }

  Future<ContentDetail?> _loadDetail(String contentId, String pluginId) async {
    final catalogId = await _catalogIdFor(contentId);
    if (catalogId.startsWith('tmdb_')) {
      final detail = await TmdbService.getDetail(
        catalogId,
        pluginId,
        client: _catalogClient,
      );
      if (detail == null || contentId == catalogId) return detail;
      // Preserve favorites/history keys while loading metadata by canonical ID.
      return ContentDetail(
        id: contentId,
        title: detail.title,
        posterUrl: detail.posterUrl,
        backdropUrl: detail.backdropUrl,
        overview: detail.overview,
        year: detail.year,
        duration: detail.duration,
        rating: detail.rating,
        type: detail.type,
        pluginId: pluginId,
        genres: detail.genres,
        cast: detail.cast,
        trailerUrl: detail.trailerUrl,
        totalSeasons: detail.totalSeasons,
        seasons: detail.seasons,
        collectionId: detail.collectionId,
        collectionName: detail.collectionName,
        similar: detail.similar,
      );
    }
    final internal = findInternalItemById(contentId);
    if (internal != null) {
      return ContentDetail(
        id: internal.id,
        title: internal.title,
        posterUrl: internal.posterUrl,
        backdropUrl: internal.backdropUrl,
        overview: internal.overview,
        year: internal.year,
        rating: internal.rating,
        type: internal.type,
        pluginId: internal.pluginId,
      );
    }
    // Plugins sem correspondência não podem substituir o título solicitado.
    if (state.installedPlugins.isEmpty) return null;
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
    await ready;
    final catalogId = await _catalogIdFor(contentId);
    if (catalogId.startsWith('tmdb_')) {
      return TmdbService.getEpisodes(
        catalogId,
        season,
        pluginId: pluginId,
        client: _catalogClient,
      );
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

  /// Prioriza fontes próprias do plugin e usa o resolvedor comum como fallback.
  Future<List<StreamSource>> getStreams(
    String contentId,
    String pluginId, {
    int? season,
    int? episode,
  }) async {
    await ready;
    AppLogger.info(
      'Solicitando fontes para $contentId, plugin $pluginId.',
      tag: 'STREAM',
    );
    // Provider-owned media takes precedence; built-in embed catalogs can still
    // use the common resolver when their own implementation has no match.
    for (final plugin in state.installedPlugins) {
      if (plugin.manifest.id != pluginId) continue;
      try {
        final ownSources = await plugin.getStreams(
          contentId,
          season: season,
          episode: episode,
        );
        if (ownSources.isNotEmpty) return ownSources;
      } catch (error, stack) {
        AppLogger.error(
          'Falha nas fontes de $pluginId (${error.runtimeType}).',
          tag: 'STREAM',
          stackTrace: stack,
        );
      }
      break;
    }
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
    final verifiedId = await _catalogIdFor(contentId);
    if (verifiedId != contentId) {
      return StreamResolverService.resolveFromContentId(
        verifiedId,
        season: season,
        episode: episode,
      );
    }
    AppLogger.warn(
      'Não foi possível identificar $contentId no EmbedMovies.',
      tag: 'STREAM',
    );
    return const [];
  }

  Future<String> _catalogIdFor(String contentId) async {
    final known =
        _resolvedCatalogIds[contentId] ??
        StreamResolverService.catalogIdFor(contentId);
    if (known != contentId || known.startsWith('tmdb_')) return known;
    final local = findInternalItemById(contentId);
    if (local == null || local.pluginId == 'org.archive.publicdomain') {
      return contentId;
    }
    final generation = _catalogGeneration;
    try {
      final results = await TmdbService.search(
        local.title,
        client: _catalogClient,
      );
      final titles = _titleKeys(local.title);
      final matches = results
          .where(
            (item) =>
                (item.type == ContentType.movie) ==
                    (local.type == ContentType.movie) &&
                local.year != null &&
                item.year == local.year &&
                _titleKeys(item.title).any(titles.contains),
          )
          .map((item) => item.id)
          .toSet();
      if (matches.length == 1 && generation == _catalogGeneration) {
        _resolvedCatalogIds[contentId] = matches.single;
        return matches.single;
      }
    } catch (error) {
      AppLogger.warn(
        'Identificação do catálogo indisponível (${error.runtimeType}).',
        tag: 'PLUGIN',
      );
    }
    return contentId;
  }

  static Set<String> _titleKeys(String title) {
    final variants = [
      title.replaceAll(RegExp(r'\([^)]*\)'), ''),
      ...RegExp(r'\(([^)]*)\)').allMatches(title).map((m) => m.group(1)!),
    ];
    String normalize(String value) {
      var result = value.toLowerCase();
      const accents = {
        'á': 'a',
        'à': 'a',
        'ã': 'a',
        'â': 'a',
        'é': 'e',
        'ê': 'e',
        'í': 'i',
        'ó': 'o',
        'ô': 'o',
        'õ': 'o',
        'ú': 'u',
        'ü': 'u',
        'ç': 'c',
      };
      accents.forEach((from, to) => result = result.replaceAll(from, to));
      return result.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    }

    return variants
        .expand((v) => [v, v.split(':').first])
        .map(normalize)
        .where((v) => v.isNotEmpty)
        .toSet();
  }

  static String _contentKey(ContentItem item) =>
      '${item.pluginId}:${item.type.value}:${item.id}';

  static String _searchContentKey(ContentItem item) {
    final canonical = StreamResolverService.catalogIdFor(item.id);
    return canonical.startsWith('tmdb_') ? canonical : _contentKey(item);
  }
}
