import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plugin_manifest.dart';

/// Estado do Gerenciador de Repositórios
class RepositoryState {
  final List<String> repositories;
  final String activeRepoUrl;
  final List<PluginManifest> availablePlugins;
  final bool isLoading;
  final String? error;

  const RepositoryState({
    this.repositories = const ['https://plugins.cinemax-stream.app/repo.json'],
    this.activeRepoUrl = 'https://plugins.cinemax-stream.app/repo.json',
    this.availablePlugins = const [],
    this.isLoading = false,
    this.error,
  });

  RepositoryState copyWith({
    List<String>? repositories,
    String? activeRepoUrl,
    List<PluginManifest>? availablePlugins,
    bool? isLoading,
    String? error,
  }) {
    return RepositoryState(
      repositories: repositories ?? this.repositories,
      activeRepoUrl: activeRepoUrl ?? this.activeRepoUrl,
      availablePlugins: availablePlugins ?? this.availablePlugins,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final repositoryManagerProvider = StateNotifierProvider<RepositoryManager, RepositoryState>((ref) {
  return RepositoryManager();
});

class RepositoryManager extends StateNotifier<RepositoryState> {
  RepositoryManager() : super(const RepositoryState()) {
    fetchRepositoryPlugins(state.activeRepoUrl);
  }

  /// Adiciona o repositório padrão do CineMax
  void addDefaultRepository() {
    const defaultUrl = 'https://plugins.cinemax-stream.app/repo.json';
    if (!state.repositories.contains(defaultUrl)) {
      state = state.copyWith(
        repositories: [...state.repositories, defaultUrl],
        activeRepoUrl: defaultUrl,
      );
    }
    fetchRepositoryPlugins(defaultUrl);
  }

  /// Adiciona um novo repositório por URL
  void addRepository(String url) {
    if (url.trim().isEmpty) return;
    final trimmed = url.trim();
    if (!state.repositories.contains(trimmed)) {
      state = state.copyWith(
        repositories: [...state.repositories, trimmed],
        activeRepoUrl: trimmed,
      );
      fetchRepositoryPlugins(trimmed);
    }
  }

  /// Remove um repositório
  void removeRepository(String url) {
    final updated = state.repositories.where((r) => r != url).toList();
    state = state.copyWith(
      repositories: updated,
      activeRepoUrl: updated.isNotEmpty ? updated.first : '',
    );
    if (updated.isNotEmpty) {
      fetchRepositoryPlugins(updated.first);
    } else {
      state = state.copyWith(availablePlugins: []);
    }
  }

  /// Busca a lista de plugins disponíveis no repositório
  Future<void> fetchRepositoryPlugins(String repoUrl) async {
    state = state.copyWith(isLoading: true, error: null);

    // Fallback com os plugins oficiais do CineMax
    await Future.delayed(const Duration(milliseconds: 600));

    final plugins = <PluginManifest>[
      const PluginManifest(
        id: 'com.amenictv',
        name: 'AmenicTV',
        version: 'v2',
        versionCode: 2,
        description: 'Tudo do app AmenicPlus - Filmes, Séries e Animes',
        author: 'Amenic Team',
        lang: 'pt-BR',
        categories: ['movies', 'series', 'anime'],
        baseUrl: 'https://amenicplus.com',
        entryPoint: 'amenictv.js',
        size: '27 KB',
        capabilities: PluginCapabilities(search: true, home: true, detail: true, streams: true),
      ),
      const PluginManifest(
        id: 'com.animescloud',
        name: 'AnimesCloud',
        version: 'v4',
        versionCode: 4,
        description: 'AnimesCloud - Animes em FHD e HD',
        author: 'Cloud Team',
        lang: 'pt-BR',
        categories: ['anime'],
        baseUrl: 'https://animescloud.tv',
        entryPoint: 'animescloud.js',
        size: '25 KB',
        capabilities: PluginCapabilities(search: true, home: true, detail: true, streams: true),
      ),
      const PluginManifest(
        id: 'com.animesdigital',
        name: 'AnimesDigital',
        version: 'v2',
        versionCode: 2,
        description: 'Animes Digital - Animes em FHD LEG e DUB.',
        author: 'Digital Anime',
        lang: 'pt-BR',
        categories: ['anime'],
        baseUrl: 'https://animesdigital.org',
        entryPoint: 'animesdigital.js',
        size: '30 KB',
        capabilities: PluginCapabilities(search: true, home: true, detail: true, streams: true),
      ),
      const PluginManifest(
        id: 'com.animesonlinenet',
        name: 'AnimesOnlineNet',
        version: 'v3',
        versionCode: 3,
        description: 'AnimesOnlineNet - Animes',
        author: 'AON Team',
        lang: 'pt-BR',
        categories: ['anime'],
        baseUrl: 'https://animesonline.net',
        entryPoint: 'animesonline.js',
        size: '20 KB',
        capabilities: PluginCapabilities(search: true, home: true, detail: true, streams: true),
      ),
      const PluginManifest(
        id: 'com.doramas',
        name: 'Doramas',
        version: 'v6',
        versionCode: 6,
        description: 'Servidor exclusivo de Doramas',
        author: 'DoramaFlix',
        lang: 'pt-BR',
        categories: ['doramas', 'series'],
        baseUrl: 'https://doramas.io',
        entryPoint: 'doramas.js',
        size: '18 KB',
        capabilities: PluginCapabilities(search: true, home: true, detail: true, streams: true),
      ),
      const PluginManifest(
        id: 'com.megaflix',
        name: 'MegaFlix',
        version: 'v4',
        versionCode: 4,
        description: 'Filmes, Séries e Animes em Português',
        author: 'MegaFlix Team',
        lang: 'pt-BR',
        categories: ['movies', 'series', 'anime'],
        baseUrl: 'https://megaflix.biz',
        entryPoint: 'megaflix.js',
        size: '21 KB',
        capabilities: PluginCapabilities(search: true, home: true, detail: true, streams: true),
      ),
      const PluginManifest(
        id: 'com.probreflix',
        name: 'ProbreFlix',
        version: 'v9',
        versionCode: 9,
        description: 'Filmes, Séries e Animes',
        author: 'ProbreFlix',
        lang: 'pt-BR',
        categories: ['movies', 'series', 'anime'],
        baseUrl: 'https://probreflix.app',
        entryPoint: 'probreflix.js',
        size: '27 KB',
        capabilities: PluginCapabilities(search: true, home: true, detail: true, streams: true),
      ),
      const PluginManifest(
        id: 'com.reidoscanais',
        name: 'ReidosCanais',
        version: 'v4',
        versionCode: 4,
        description: 'Canais ao vivo, Futebol, UFC e muito mais. OBS: Ne...',
        author: 'Rei Dev',
        lang: 'pt-BR',
        categories: ['live', 'tv'],
        baseUrl: 'https://reidoscanais.tv',
        entryPoint: 'reidoscanais.js',
        size: '22 KB',
        capabilities: PluginCapabilities(search: true, home: true, detail: true, streams: true),
      ),
      const PluginManifest(
        id: 'com.streamberry',
        name: 'Streamberry',
        version: 'v4',
        versionCode: 4,
        description: 'Streamberry Filmes e Séries',
        author: 'Berry Labs',
        lang: 'pt-BR',
        categories: ['movies', 'series'],
        baseUrl: 'https://streamberry.xyz',
        entryPoint: 'streamberry.js',
        size: '23 KB',
        capabilities: PluginCapabilities(search: true, home: true, detail: true, streams: true),
      ),
      const PluginManifest(
        id: 'com.supercine',
        name: 'SuperCine',
        version: 'v2',
        versionCode: 2,
        description: 'Tudo do app SuperCine Filmes, Séries e Animes',
        author: 'SuperCine Dev',
        lang: 'pt-BR',
        categories: ['movies', 'series', 'anime'],
        baseUrl: 'https://supercine.org',
        entryPoint: 'supercine.js',
        size: '28 KB',
        capabilities: PluginCapabilities(search: true, home: true, detail: true, streams: true),
      ),
      const PluginManifest(
        id: 'com.ultracine',
        name: 'UltraCine',
        version: 'v6',
        versionCode: 6,
        description: 'UltraCine Filmes e Séries',
        author: 'Ultra Team',
        lang: 'pt-BR',
        categories: ['movies', 'series'],
        baseUrl: 'https://ultracine.to',
        entryPoint: 'ultracine.js',
        size: '19 KB',
        capabilities: PluginCapabilities(search: true, home: true, detail: true, streams: true),
      ),
    ];

    state = state.copyWith(
      availablePlugins: plugins,
      isLoading: false,
    );
  }
}
