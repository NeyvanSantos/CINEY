/// Manifesto de um plugin
/// Define metadados e capacidades do plugin
class PluginManifest {
  final String id;
  final String name;
  final String version;
  final int versionCode;
  final String description;
  final String author;
  final String lang;
  final String? iconUrl;
  final List<String> categories;
  final String baseUrl;
  final PluginCapabilities capabilities;
  final String entryPoint;
  final String? size;

  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.versionCode,
    required this.description,
    required this.author,
    required this.lang,
    this.iconUrl,
    required this.categories,
    required this.baseUrl,
    required this.capabilities,
    required this.entryPoint,
    this.size,
  });

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    return PluginManifest(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      version: json['version']?.toString() ?? '1',
      versionCode: json['versionCode'] as int? ?? 1,
      description: json['description']?.toString() ?? '',
      author: json['author']?.toString() ?? 'Desconhecido',
      lang: json['lang']?.toString() ?? 'pt-BR',
      iconUrl: json['icon']?.toString(),
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['movies'],
      baseUrl: json['baseUrl']?.toString() ?? '',
      capabilities: PluginCapabilities.fromJson(
          json['capabilities'] as Map<String, dynamic>? ?? {}),
      entryPoint: json['entryPoint']?.toString() ?? 'plugin.js',
      size: json['size']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'versionCode': versionCode,
      'description': description,
      'author': author,
      'lang': lang,
      'icon': iconUrl,
      'categories': categories,
      'baseUrl': baseUrl,
      'capabilities': capabilities.toJson(),
      'entryPoint': entryPoint,
      'size': size,
    };
  }

  /// Flag de idioma (emoji)
  String get langFlag {
    switch (lang.toLowerCase()) {
      case 'pt-br':
      case 'pt':
        return '🇧🇷';
      case 'en':
      case 'en-us':
        return '🇺🇸';
      case 'es':
        return '🇪🇸';
      case 'ja':
        return '🇯🇵';
      case 'ko':
        return '🇰🇷';
      default:
        return '🌐';
    }
  }

  /// Label de idioma
  String get langLabel {
    switch (lang.toLowerCase()) {
      case 'pt-br':
        return 'português (Brasil)';
      case 'pt':
        return 'português';
      case 'en':
      case 'en-us':
        return 'English';
      case 'es':
        return 'español';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';
      default:
        return lang;
    }
  }
}

/// Capacidades que um plugin pode oferecer
class PluginCapabilities {
  final bool search;
  final bool home;
  final bool detail;
  final bool streams;
  final bool episodes;
  final bool subtitles;

  const PluginCapabilities({
    this.search = false,
    this.home = false,
    this.detail = false,
    this.streams = false,
    this.episodes = false,
    this.subtitles = false,
  });

  factory PluginCapabilities.fromJson(Map<String, dynamic> json) {
    return PluginCapabilities(
      search: json['search'] == true,
      home: json['home'] == true,
      detail: json['detail'] == true,
      streams: json['streams'] == true,
      episodes: json['episodes'] == true,
      subtitles: json['subtitles'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'search': search,
      'home': home,
      'detail': detail,
      'streams': streams,
      'episodes': episodes,
      'subtitles': subtitles,
    };
  }
}

/// Modelo de um Repositório de Plugins
class PluginRepository {
  final String name;
  final String? author;
  final String? description;
  final String url;
  final List<PluginRepositoryEntry> plugins;

  const PluginRepository({
    required this.name,
    this.author,
    this.description,
    required this.url,
    required this.plugins,
  });

  factory PluginRepository.fromJson(Map<String, dynamic> json, String repoUrl) {
    return PluginRepository(
      name: json['name']?.toString() ?? 'Repositório',
      author: json['author']?.toString(),
      description: json['description']?.toString(),
      url: repoUrl,
      plugins: (json['plugins'] as List<dynamic>?)
              ?.map((e) => PluginRepositoryEntry.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Entrada de plugin dentro de um repositório
class PluginRepositoryEntry {
  final String id;
  final String manifestUrl;
  final String scriptUrl;
  final String? iconUrl;

  const PluginRepositoryEntry({
    required this.id,
    required this.manifestUrl,
    required this.scriptUrl,
    this.iconUrl,
  });

  factory PluginRepositoryEntry.fromJson(Map<String, dynamic> json) {
    return PluginRepositoryEntry(
      id: json['id']?.toString() ?? '',
      manifestUrl: json['manifest']?.toString() ?? '',
      scriptUrl: json['script']?.toString() ?? '',
      iconUrl: json['icon']?.toString(),
    );
  }
}
