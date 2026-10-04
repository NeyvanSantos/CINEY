import '../contracts/plugin_interface.dart';
import '../models/content_item.dart';
import '../models/plugin_manifest.dart';
import '../models/stream_source.dart';
import '../runtime/stream_resolver.dart';
import '../runtime/tmdb_service.dart';

/// Plugin Base com suporte a streaming via embed (mesmo método do CloudStream/Stremio)
abstract class BaseScraperPlugin implements PluginInterface {
  @override
  Future<List<StreamSource>> getStreams(
    String contentId, {
    int? season,
    int? episode,
  }) async {
    // Tenta resolver via embed providers usando TMDB ID
    final embedSources = StreamResolverService.resolveFromContentId(
      contentId,
      season: season,
      episode: episode,
    );

    if (embedSources.isNotEmpty) {
      return embedSources;
    }

    // Do not pretend a demo video is the requested title.
    return const [];
  }
}

/// 🎬 Plugin: MegaFlix (Filmes e Blockbusters)
class MegaFlixPlugin extends BaseScraperPlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'com.megaflix',
    name: 'MegaFlix',
    version: 'v4',
    versionCode: 4,
    description: 'Filmes, Séries e Blockbusters em Alta Definição',
    author: 'MegaFlix Team',
    lang: 'pt-BR',
    iconUrl:
        'https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=100&auto=format&fit=crop&q=60',
    categories: ['movies', 'series', 'action', 'scifi'],
    baseUrl: 'https://megaflix.biz',
    entryPoint: 'megaflix.js',
    size: '21 KB',
    capabilities: PluginCapabilities(
      search: true,
      home: true,
      detail: true,
      streams: true,
      episodes: true,
    ),
  );

  static final List<ContentItem> movies = [
    const ContentItem(
      id: 'mf_1',
      title: 'Duna: Parte 2',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/8b8R8l88Qje9dn9OE8PY05Nxl1X.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/xOMo8BRK7PfcJv9JCnx7s5hj0PX.jpg',
      year: '2024',
      rating: 8.4,
      type: ContentType.movie,
      pluginId: 'com.megaflix',
      overview:
          'Paul Atreides se une a Chani e aos Fremen em busca de vingança contra os conspiradores que destruíram sua família.',
    ),
    const ContentItem(
      id: 'mf_2',
      title: 'Deadpool & Wolverine',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/8cdWjvZQUExUUTzyp4t6EDMubfO.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/yDHYTfa2wfLveKMYXQIUTKiwnBa.jpg',
      year: '2024',
      rating: 8.0,
      type: ContentType.movie,
      pluginId: 'com.megaflix',
      overview:
          'Wolverine se recupera de seus ferimentos quando cruza o caminho com Deadpool.',
    ),
    const ContentItem(
      id: 'mf_3',
      title: 'Gladiador II',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/2cxhvwyEwRlysAmRH4iodkvo0z5.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/euYIwmwkmz95mnXvufEmbL69ovr.jpg',
      year: '2024',
      rating: 7.9,
      type: ContentType.movie,
      pluginId: 'com.megaflix',
      overview:
          'Anos após a morte de Maximus, Lucius deve entrar no Coliseu para lutar pela honra de Roma.',
    ),
    const ContentItem(
      id: 'mf_4',
      title: 'Oppenheimer',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg',
      year: '2023',
      rating: 8.9,
      type: ContentType.movie,
      pluginId: 'com.megaflix',
      overview:
          'A história do físico americano J. Robert Oppenheimer e seu papel no desenvolvimento da bomba atômica.',
    ),
    const ContentItem(
      id: 'mf_5',
      title: 'Interestelar',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/rAiYT5KGqDCRIIqo664sY9XZIvQ.jpg',
      year: '2014',
      rating: 9.0,
      type: ContentType.movie,
      pluginId: 'com.megaflix',
      overview:
          'Um grupo de exploradores faz uso de um buraco de minhoca recém-descoberto para superar as limitações das viagens espaciais humanas.',
    ),
    const ContentItem(
      id: 'mf_6',
      title: 'Vingadores: Ultimato',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/q6725aR8Zs4IwGMXzZT8aC8lh41.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/7RyHsO4yDXtBv1zUU3mTpHeQ0d5.jpg',
      year: '2019',
      rating: 8.9,
      type: ContentType.movie,
      pluginId: 'com.megaflix',
      overview:
          'Após os eventos devastadores de Guerra Infinita, os Vingadores se reúnem mais uma vez para desfazer as ações de Thanos.',
    ),
    const ContentItem(
      id: 'mf_7',
      title: 'Batman (The Batman)',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/wd7B4R4qlAL2Cr2rSpVBsTB3Sp1.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/b0PlSFdDwbyK0cf5RxwDpaOJQvQ.jpg',
      year: '2022',
      rating: 8.1,
      type: ContentType.movie,
      pluginId: 'com.megaflix',
      overview:
          'Em seu segundo ano de combate ao crime, Batman desvenda a corrupção em Gotham City conectada à sua própria família.',
    ),
    const ContentItem(
      id: 'mf_8',
      title: 'John Wick 4: Baba Yaga',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/gh2bmprLtUQ8o9v59emcsW3v5vH.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/7I6VUdPj6tQECNHdviJkUHD2389.jpg',
      year: '2023',
      rating: 8.4,
      type: ContentType.movie,
      pluginId: 'com.megaflix',
      overview:
          'John Wick descobre um caminho para derrotar a Alta Cúpula e conquistar sua liberdade definitiva.',
    ),
    const ContentItem(
      id: 'mf_9',
      title: 'Top Gun: Maverick',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/jmlvd51GpHh6AClh6qI5aA4qIu9.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/odJ4hx6g6vBt4lBWKFD1tI8WS4x.jpg',
      year: '2022',
      rating: 8.6,
      type: ContentType.movie,
      pluginId: 'com.megaflix',
      overview:
          'Após mais de trinta anos de serviço como um dos melhores aviadores da Marinha, Pete Mitchell está onde pertence.',
    ),
    const ContentItem(
      id: 'mf_10',
      title: 'A Origem (Inception)',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/s3TBrRGB1iav7gFOCNx3H31MoES.jpg',
      year: '2010',
      rating: 8.8,
      type: ContentType.movie,
      pluginId: 'com.megaflix',
      overview:
          'Um ladrão que rouba segredos corporativos através do uso da tecnologia de compartilhamento de sonhos recebe a tarefa de plantar uma ideia.',
    ),
  ];

  @override
  Future<List<ContentCategory>> getHome() async {
    final liveTrending = await TmdbService.getTrendingMovies(
      pluginId: manifest.id,
    );
    final items = liveTrending.isNotEmpty ? liveTrending : movies;

    return [
      ContentCategory(
        name: '🔥 Destaques da Semana',
        items: items.take(6).toList(),
      ),
      ContentCategory(name: '🎬 Filmes de Ação & Blockbusters', items: movies),
    ];
  }

  @override
  Future<List<ContentItem>> search(String query, {int page = 1}) async {
    final live = await TmdbService.search(query, pluginId: manifest.id);
    if (live.isNotEmpty) return live;
    return movies
        .where((i) => i.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Future<ContentDetail> getDetail(String contentId) async {
    if (contentId.startsWith('tmdb_')) {
      final liveDetail = await TmdbService.getDetail(contentId, manifest.id);
      if (liveDetail != null) return liveDetail;
    }

    final match = movies.where((i) => i.id == contentId);
    final item = match.isNotEmpty ? match.first : movies.first;

    return ContentDetail(
      id: item.id,
      title: item.title,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl,
      overview:
          item.overview ??
          'Filme emocionante com qualidade master e áudio multicanal.',
      year: item.year ?? '2024',
      duration: '2h 20m',
      rating: item.rating ?? 8.5,
      type: item.type,
      pluginId: manifest.id,
      genres: const ['Ação', 'Ficção Científica', 'Aventura'],
      cast: const [
        CastMember(
          name: 'Ator Principal',
          character: 'Protagonista',
          photoUrl:
              'https://image.tmdb.org/t/p/w200/BE2sdjpgsa2rNTFa66f7upkaOP.jpg',
        ),
        CastMember(
          name: 'Atriz Principal',
          character: 'Co-protagonista',
          photoUrl:
              'https://image.tmdb.org/t/p/w200/r3A7evZyTGaNuQBT5vGz093Zezr.jpg',
        ),
      ],
    );
  }

  @override
  Future<List<ContentItem>> getEpisodes(String seriesId, int season) async =>
      [];
}

/// 📺 Plugin: SuperCine (Séries & Dramas Populares)
class SuperCinePlugin extends BaseScraperPlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'com.supercine',
    name: 'SuperCine',
    version: 'v2',
    versionCode: 2,
    description: 'Séries Populares, Épicas e Lançamentos Exclusivos',
    author: 'SuperCine Dev',
    lang: 'pt-BR',
    iconUrl:
        'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=100&auto=format&fit=crop&q=60',
    categories: ['series', 'drama', 'fantasy'],
    baseUrl: 'https://supercine.org',
    entryPoint: 'supercine.js',
    size: '28 KB',
    capabilities: PluginCapabilities(
      search: true,
      home: true,
      detail: true,
      streams: true,
      episodes: true,
    ),
  );

  static final List<ContentItem> seriesList = [
    const ContentItem(
      id: 'sc_1',
      title: 'A Casa do Dragão (House of the Dragon)',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/t9Xke5UNqTq62Udua6q8090ffTi.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/etjA2BvmkFmzNVp5pBvFm9y1Ld.jpg',
      year: '2024',
      rating: 8.5,
      type: ContentType.series,
      pluginId: 'com.supercine',
      overview:
          'A história da guerra civil Targaryen que ocorreu cerca de 200 anos antes dos eventos de Game of Thrones.',
    ),
    const ContentItem(
      id: 'sc_2',
      title: 'Stranger Things',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/49WJfeN0moxb9IPfGn8AIqMGskD.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/56v2KjBlU4XaOv9rVYEQypROD7P.jpg',
      year: '2024',
      rating: 8.6,
      type: ContentType.series,
      pluginId: 'com.supercine',
      overview:
          'Quando um garoto desaparece, a cidade desvenda um mistério envolvendo experimentos secretos e forças sobrenaturais.',
    ),
    const ContentItem(
      id: 'sc_3',
      title: 'The Boys',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/2zmTngn1tYC1AvfnNDBpQI7V184.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/7d6eUD1R8r0l6gV2RIMvFnNbyMz.jpg',
      year: '2024',
      rating: 8.7,
      type: ContentType.series,
      pluginId: 'com.supercine',
      overview:
          'Um grupo de vigilantes se propõe a derrubar super-heróis corruptos que abusam de seus superpoderes.',
    ),
    const ContentItem(
      id: 'sc_4',
      title: 'The Last of Us',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/uKvVjHNqB5VmOrdxqAt2V7JMrne.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/uDgy6hyPd82kOHh6I95FLtLnj6p.jpg',
      year: '2023',
      rating: 8.7,
      type: ContentType.series,
      pluginId: 'com.supercine',
      overview:
          'Joel e Ellie sobrevivem em um mundo pós-pandêmico cruel enquanto viajam pelos Estados Unidos.',
    ),
    const ContentItem(
      id: 'sc_5',
      title: 'Breaking Bad',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/ztkUQFLlC19CCMYHW9o1zWhJRNq.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg',
      year: '2013',
      rating: 9.3,
      type: ContentType.series,
      pluginId: 'com.supercine',
      overview:
          'Um professor de química com câncer terminal se une a um ex-aluno para fabricar e vender metanfetamina.',
    ),
    const ContentItem(
      id: 'sc_6',
      title: 'Game of Thrones',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg',
      year: '2019',
      rating: 9.0,
      type: ContentType.series,
      pluginId: 'com.supercine',
      overview:
          'Nove famílias nobres lutam pelo controle das terras místicas de Westeros.',
    ),
    const ContentItem(
      id: 'sc_7',
      title: 'Wandinha (Wednesday)',
      posterUrl: 'https://image.tmdb.org/t/p/w500/9PFonQ95Wb0b5565Z54p555.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/iHSwvRVsRyxpX7FE7GbviaDvgGZ.jpg',
      year: '2022',
      rating: 8.4,
      type: ContentType.series,
      pluginId: 'com.supercine',
      overview:
          'Inteligente, sarcástica e um pouco morta por dentro, Wandinha investiga uma onda de assassinatos na Escola Nunca Mais.',
    ),
    const ContentItem(
      id: 'sc_8',
      title: 'Loki',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/voHUmluYmKyleFk9a3Zs0vNxv20.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/b9UCf9er9yh56qM2AsSpL2gf41a.jpg',
      year: '2023',
      rating: 8.2,
      type: ContentType.series,
      pluginId: 'com.supercine',
      overview:
          'O vilão Loki retoma seu papel como o Deus da Trapaça após os eventos de Vingadores: Ultimato.',
    ),
  ];

  @override
  Future<List<ContentCategory>> getHome() async {
    final liveSeries = await TmdbService.getTrendingSeries(
      pluginId: manifest.id,
    );
    final items = liveSeries.isNotEmpty ? liveSeries : seriesList;

    return [
      ContentCategory(name: '📺 Séries em Destaque & Populares', items: items),
    ];
  }

  @override
  Future<List<ContentItem>> search(String query, {int page = 1}) async {
    final live = await TmdbService.search(query, pluginId: manifest.id);
    if (live.isNotEmpty) return live;
    return seriesList
        .where((i) => i.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Future<ContentDetail> getDetail(String contentId) async {
    if (contentId.startsWith('tmdb_')) {
      final liveDetail = await TmdbService.getDetail(contentId, manifest.id);
      if (liveDetail != null) return liveDetail;
    }

    final match = seriesList.where((i) => i.id == contentId);
    final item = match.isNotEmpty ? match.first : seriesList.first;

    return ContentDetail(
      id: item.id,
      title: item.title,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl,
      overview:
          item.overview ??
          'Série aclamada internacionalmente com temporadas completas.',
      year: item.year ?? '2024',
      duration: '4 Temporadas',
      rating: item.rating ?? 8.7,
      type: ContentType.series,
      pluginId: manifest.id,
      genres: const ['Drama', 'Ficção Científica', 'Mistério'],
      totalSeasons: 4,
      seasons: const [
        Season(number: 1, name: 'Temporada 1', episodeCount: 8),
        Season(number: 2, name: 'Temporada 2', episodeCount: 9),
        Season(number: 3, name: 'Temporada 3', episodeCount: 8),
        Season(number: 4, name: 'Temporada 4', episodeCount: 9),
      ],
    );
  }

  @override
  Future<List<ContentItem>> getEpisodes(String seriesId, int season) async {
    return List.generate(
      8,
      (index) => ContentItem(
        id: 'ep_${seriesId}_${season}_${index + 1}',
        title: 'Episódio ${index + 1} - Temporada $season',
        posterUrl:
            'https://image.tmdb.org/t/p/w500/49WJfeN0moxb9IPfGn8AIqMGskD.jpg',
        year: '2024',
        type: ContentType.series,
        pluginId: manifest.id,
        overview:
            'Episódio completo em alta definição com legendas e dublagem em português.',
      ),
    );
  }
}

/// 🌸 Plugin: AnimesCloud (Animes Dublados & Legendados)
class AnimesCloudPlugin extends BaseScraperPlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'com.animescloud',
    name: 'AnimesCloud',
    version: 'v4',
    versionCode: 4,
    description: 'Animes em FHD e HD Dublado e Legendado',
    author: 'Cloud Team',
    lang: 'pt-BR',
    iconUrl:
        'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=100&auto=format&fit=crop&q=60',
    categories: ['anime'],
    baseUrl: 'https://animescloud.tv',
    entryPoint: 'animescloud.js',
    size: '25 KB',
    capabilities: PluginCapabilities(
      search: true,
      home: true,
      detail: true,
      streams: true,
      episodes: true,
    ),
  );

  static final List<ContentItem> animesList = [
    const ContentItem(
      id: 'ac_1',
      title: 'Demon Slayer: Kimetsu no Yaiba',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/xUfRZu2mi8jH6SzQEJGP6tjBuYj.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/nTvM4mhqZlHIkw296GooEH92drq.jpg',
      year: '2024',
      rating: 8.8,
      type: ContentType.anime,
      pluginId: 'com.animescloud',
      overview:
          'Tanjiro Kamado luta contra demônios e busca a cura para transformar sua irmã Nezuko de volta em humana.',
    ),
    const ContentItem(
      id: 'ac_2',
      title: 'Attack on Titan (Shingeki no Kyojin)',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/hTP1DtLGFamjfu8WqjnuQdP1n4i.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/sHim6U0ANsbzxcmKAuEUhYgmNKn.jpg',
      year: '2023',
      rating: 9.1,
      type: ContentType.anime,
      pluginId: 'com.animescloud',
      overview:
          'A humanidade vive dentro de muralhas para se proteger dos titãs devoradores de homens.',
    ),
    const ContentItem(
      id: 'ac_3',
      title: 'Jujutsu Kaisen',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/hFWP5HkbVEe40hrXgtCeQxo94lp.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/mIBnOYuUnK5kbIkMCVP4EoxuGJm.jpg',
      year: '2024',
      rating: 8.7,
      type: ContentType.anime,
      pluginId: 'com.animescloud',
      overview:
          'Um garoto engole um dedo amaldiçoado e entra para uma escola secreta de feiticeiros.',
    ),
    const ContentItem(
      id: 'ac_4',
      title: 'Solo Leveling',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/geCRueV3ElhRTr0xtJuPxJ8iG5N.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/geCRueV3ElhRTr0xtJuPxJ8iG5N.jpg',
      year: '2024',
      rating: 8.6,
      type: ContentType.anime,
      pluginId: 'com.animescloud',
      overview:
          'O caçador mais fraco do mundo ganha a capacidade de evoluir infinitamente.',
    ),
    const ContentItem(
      id: 'ac_5',
      title: 'One Piece',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/fcXdJUSDiC01jg3eL0wUUR2V26p.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/4HodYYKEIsGOdinkGi2Ucz6X9i0.jpg',
      year: '2024',
      rating: 8.9,
      type: ContentType.anime,
      pluginId: 'com.animescloud',
      overview:
          'Monkey D. Luffy e seus companheiros piratas navegam pelos mares em busca do tesouro supremo, o One Piece.',
    ),
    const ContentItem(
      id: 'ac_6',
      title: 'Naruto Shippuden',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/xhy4alMtzFvA3Ncrg9l3nL8V83m.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/d762x8i7eL7Z2W3M8s26W.jpg',
      year: '2017',
      rating: 8.8,
      type: ContentType.anime,
      pluginId: 'com.animescloud',
      overview:
          'Naruto Uzumaki retorna para defender a Vila da Folha e resgatar seu amigo Sasuke.',
    ),
    const ContentItem(
      id: 'ac_7',
      title: 'Chainsaw Man',
      posterUrl: 'https://image.tmdb.org/t/p/w500/npdB6eFz4qt9CdG6o49um20.jpg',
      backdropUrl: 'https://image.tmdb.org/t/p/original/v5e1bK1B6.jpg',
      year: '2022',
      rating: 8.6,
      type: ContentType.anime,
      pluginId: 'com.animescloud',
      overview:
          'Denji renasce como um híbrido de homem e demônio motosserra para caçar criaturas do submundo.',
    ),
  ];

  @override
  Future<List<ContentCategory>> getHome() async {
    final liveAnimes = await TmdbService.getPopularAnimes(
      pluginId: manifest.id,
    );
    final items = liveAnimes.isNotEmpty ? liveAnimes : animesList;

    return [
      ContentCategory(name: '🌸 Animes Populares & Lançamentos', items: items),
    ];
  }

  @override
  Future<List<ContentItem>> search(String query, {int page = 1}) async {
    final live = await TmdbService.search(query, pluginId: manifest.id);
    if (live.isNotEmpty) return live;
    return animesList
        .where((i) => i.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Future<ContentDetail> getDetail(String contentId) async {
    if (contentId.startsWith('tmdb_')) {
      final liveDetail = await TmdbService.getDetail(contentId, manifest.id);
      if (liveDetail != null) return liveDetail;
    }

    final match = animesList.where((i) => i.id == contentId);
    final item = match.isNotEmpty ? match.first : animesList.first;

    return ContentDetail(
      id: item.id,
      title: item.title,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl,
      overview:
          item.overview ??
          'Anime de sucesso absoluto com episódios dublados e legendados.',
      year: item.year ?? '2024',
      duration: '4 Temporadas',
      rating: item.rating ?? 8.8,
      type: ContentType.anime,
      pluginId: manifest.id,
      genres: const ['Anime', 'Ação', 'Fantasia', 'Sobrenatural'],
      totalSeasons: 4,
    );
  }

  @override
  Future<List<ContentItem>> getEpisodes(String seriesId, int season) async {
    return List.generate(
      12,
      (i) => ContentItem(
        id: 'ac_ep_${seriesId}_${season}_${i + 1}',
        title: 'Episódio ${i + 1}',
        posterUrl:
            'https://image.tmdb.org/t/p/w500/xUfRZu2mi8jH6SzQEJGP6tjBuYj.jpg',
        type: ContentType.anime,
        pluginId: manifest.id,
        overview:
            'Episódio completo em Full HD com áudio original em japonês e dublagem PT-BR.',
      ),
    );
  }
}

/// 🎎 Plugin: Doramas (K-Dramas & Séries Asiáticas)
class DoramasPlugin extends BaseScraperPlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'com.doramas',
    name: 'Doramas',
    version: 'v6',
    versionCode: 6,
    description: 'Servidor exclusivo de Doramas e Dramas Asiáticos',
    author: 'DoramaFlix Team',
    lang: 'pt-BR',
    iconUrl:
        'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=100&auto=format&fit=crop&q=60',
    categories: ['dorama', 'series'],
    baseUrl: 'https://doramas.io',
    entryPoint: 'doramas.js',
    size: '18 KB',
    capabilities: PluginCapabilities(
      search: true,
      home: true,
      detail: true,
      streams: true,
      episodes: true,
    ),
  );

  static final List<ContentItem> doramasList = [
    const ContentItem(
      id: 'dr_1',
      title: 'Rainha das Lágrimas (Queen of Tears)',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/jFEPOKMfBTvhIGIo7YNJ5FaZSQs.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/raN3IFgpEcpHnNUt7dMItSMLrkY.jpg',
      year: '2024',
      rating: 8.9,
      type: ContentType.dorama,
      pluginId: 'com.doramas',
      overview:
          'A rainha das lojas de departamento e seu marido do interior enfrentam uma crise conjugal até o amor reflorescer.',
    ),
    const ContentItem(
      id: 'dr_2',
      title: 'Pousando no Amor (Crash Landing on You)',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/dvSbqR2yNVsYVFn5CGfpnRqIPwT.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/kEl2t3OhXc3Zb9FBh1AuYzRTgZp.jpg',
      year: '2020',
      rating: 8.8,
      type: ContentType.dorama,
      pluginId: 'com.doramas',
      overview:
          'Uma herdeira sul-coreana sofre um acidente de parapente e cai na Coreia do Norte.',
    ),
    const ContentItem(
      id: 'dr_3',
      title: 'Alquimia das Almas',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/q2IiPRaOdCOm1civBEWoBcFMon3.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/w2mMhaSWRYMNJIz2BXII0YmNWnN.jpg',
      year: '2023',
      rating: 8.7,
      type: ContentType.dorama,
      pluginId: 'com.doramas',
      overview:
          'Uma feiticeira poderosa no corpo de uma mulher cega se envolve com um nobre que busca sua ajuda.',
    ),
    const ContentItem(
      id: 'dr_4',
      title: 'All of Us Are Dead (Estamos Mortos)',
      posterUrl: 'https://image.tmdb.org/t/p/w500/pTEr0494x7p02j09a0.jpg',
      backdropUrl: 'https://image.tmdb.org/t/p/original/9r1w2e3.jpg',
      year: '2022',
      rating: 8.4,
      type: ContentType.dorama,
      pluginId: 'com.doramas',
      overview: 'Uma escola se torna o epicentro de um surto de vírus zumbi.',
    ),
  ];

  @override
  Future<List<ContentCategory>> getHome() async {
    final liveDoramas = await TmdbService.getPopularDoramas(
      pluginId: manifest.id,
    );
    final items = liveDoramas.isNotEmpty ? liveDoramas : doramasList;

    return [
      ContentCategory(name: '✨ K-Dramas e Doramas em Alta', items: items),
    ];
  }

  @override
  Future<List<ContentItem>> search(String query, {int page = 1}) async {
    final live = await TmdbService.search(query, pluginId: manifest.id);
    if (live.isNotEmpty) return live;
    return doramasList
        .where((i) => i.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Future<ContentDetail> getDetail(String contentId) async {
    if (contentId.startsWith('tmdb_')) {
      final liveDetail = await TmdbService.getDetail(contentId, manifest.id);
      if (liveDetail != null) return liveDetail;
    }

    final match = doramasList.where((i) => i.id == contentId);
    final item = match.isNotEmpty ? match.first : doramasList.first;

    return ContentDetail(
      id: item.id,
      title: item.title,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl,
      overview:
          item.overview ?? 'Dorama emocionante com atuações de grande sucesso.',
      year: item.year ?? '2024',
      duration: '16 Episódios',
      rating: item.rating ?? 8.8,
      type: ContentType.dorama,
      pluginId: manifest.id,
      genres: const ['Romance', 'Drama', 'Fantasia'],
      totalSeasons: 1,
    );
  }

  @override
  Future<List<ContentItem>> getEpisodes(String seriesId, int season) async {
    return List.generate(
      16,
      (i) => ContentItem(
        id: 'dr_ep_${seriesId}_${season}_${i + 1}',
        title: 'Episódio ${i + 1}',
        posterUrl:
            'https://image.tmdb.org/t/p/w500/jFEPOKMfBTvhIGIo7YNJ5FaZSQs.jpg',
        type: ContentType.dorama,
        pluginId: manifest.id,
      ),
    );
  }
}

/// 🎬 Plugin: AmenicTV (Animações, Família e Comédia)
class AmenicTVPlugin extends BaseScraperPlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'com.amenictv',
    name: 'AmenicTV',
    version: 'v2',
    versionCode: 2,
    description: 'Animações, Filmes Infantis e Para a Família',
    author: 'Amenic Team',
    lang: 'pt-BR',
    iconUrl:
        'https://images.unsplash.com/photo-1522869635100-9f4c5e86aa37?w=100&auto=format&fit=crop&q=60',
    categories: ['movies', 'animation', 'family'],
    baseUrl: 'https://amenicplus.com',
    entryPoint: 'amenictv.js',
    size: '27 KB',
    capabilities: PluginCapabilities(
      search: true,
      home: true,
      detail: true,
      streams: true,
    ),
  );

  static final List<ContentItem> animationsList = [
    const ContentItem(
      id: 'am_1',
      title: 'Moana 2',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/4YZpsylIHsvQwVFR9PtSayQCHO5.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/tElnmtQ6yz1PjN1kePNt8cuGIah.jpg',
      year: '2024',
      rating: 7.2,
      type: ContentType.movie,
      pluginId: 'com.amenictv',
      overview:
          'Moana embarca em uma nova jornada pelos mares da Oceania após receber um chamado inesperado de seus ancestrais.',
    ),
    const ContentItem(
      id: 'am_2',
      title: 'Divertida Mente 2',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/vpnVM9B6NMmQpWeZvzLvDESb2QY.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/stKGOm8wqGGOvEj9hn72EAvUR99.jpg',
      year: '2024',
      rating: 8.1,
      type: ContentType.movie,
      pluginId: 'com.amenictv',
      overview:
          'Com a chegada da adolescência, novas emoções como a Ansiedade assumem a sala de comando.',
    ),
    const ContentItem(
      id: 'am_3',
      title: 'Super Mario Bros. O Filme',
      posterUrl: 'https://image.tmdb.org/t/p/w500/i9Y5nS1V000V0p09y.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/9n2tJBplPbgR2ca0599W.jpg',
      year: '2023',
      rating: 7.8,
      type: ContentType.movie,
      pluginId: 'com.amenictv',
      overview:
          'Mario e Luigi vão parar no Reino dos Cogumelos e precisam salvar a Princesa Peach do terrível Bowser.',
    ),
    const ContentItem(
      id: 'am_4',
      title: 'Homem-Aranha: Através do Aranhaverso',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/8Vt6mWEReuy4Of61Lnj5Xj704m8.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/4HodYYKEIsGOdinkGi2Ucz6X9i0.jpg',
      year: '2023',
      rating: 8.8,
      type: ContentType.movie,
      pluginId: 'com.amenictv',
      overview:
          'Miles Morales é catapultado através do Multiverso onde encontra uma equipe de Pessoas-Aranha.',
    ),
  ];

  @override
  Future<List<ContentCategory>> getHome() async {
    final live = await TmdbService.getAnimationMovies(pluginId: manifest.id);
    final items = live.isNotEmpty ? live : animationsList;

    return [
      ContentCategory(
        name: '🍿 Animações & Clássicos da Família',
        items: items,
      ),
    ];
  }

  @override
  Future<List<ContentItem>> search(String query, {int page = 1}) async =>
      animationsList
          .where((i) => i.title.toLowerCase().contains(query.toLowerCase()))
          .toList();

  @override
  Future<ContentDetail> getDetail(String contentId) async {
    if (contentId.startsWith('tmdb_')) {
      final live = await TmdbService.getDetail(contentId, manifest.id);
      if (live != null) return live;
    }
    final match = animationsList.where((i) => i.id == contentId);
    final item = match.isNotEmpty ? match.first : animationsList.first;
    return ContentDetail(
      id: item.id,
      title: item.title,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl,
      overview: item.overview,
      year: item.year,
      rating: item.rating,
      type: item.type,
      pluginId: manifest.id,
      genres: const ['Animação', 'Aventura', 'Comédia', 'Família'],
    );
  }

  @override
  Future<List<ContentItem>> getEpisodes(String seriesId, int season) async =>
      [];
}

/// 🎬 Plugin: ProbreFlix (Lançamentos e Ficção Científica)
class ProbreFlixPlugin extends BaseScraperPlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'com.probreflix',
    name: 'ProbreFlix',
    version: 'v9',
    versionCode: 9,
    description: 'Lançamentos de Cinema, Sci-Fi e Séries',
    author: 'ProbreFlix Com',
    lang: 'pt-BR',
    iconUrl:
        'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=100&auto=format&fit=crop&q=60',
    categories: ['movies', 'series', 'scifi'],
    baseUrl: 'https://probreflix.app',
    entryPoint: 'probreflix.js',
    size: '27 KB',
    capabilities: PluginCapabilities(
      search: true,
      home: true,
      detail: true,
      streams: true,
    ),
  );

  static final List<ContentItem> probreList = [
    const ContentItem(
      id: 'pf_1',
      title: 'Coringa: Delírio a Dois',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/aciP8Km0waTLXEYf5zyFKxRLx2n.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/uGmYqxh8flqkM27v4HQoGhVi4ez.jpg',
      year: '2024',
      rating: 6.2,
      type: ContentType.movie,
      pluginId: 'com.probreflix',
      overview:
          'Arthur Fleck aguarda julgamento no Asilo Arkham quando conhece o amor de sua vida, Arlequina.',
    ),
    const ContentItem(
      id: 'pf_2',
      title: 'Arcane: League of Legends',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/abf8tHznhSvl9BAElD23cQ89pfv.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/fqldfq2nqXY0ek5N0v95rN.jpg',
      year: '2024',
      rating: 9.0,
      type: ContentType.series,
      pluginId: 'com.probreflix',
      overview:
          'Duas irmãs lutam em lados opostos de uma guerra entre tecnologias mágicas e convicções incompatíveis.',
    ),
    const ContentItem(
      id: 'pf_3',
      title: 'Matrix (The Matrix)',
      posterUrl: 'https://image.tmdb.org/t/p/w500/lDqMDI8888019.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/7RyHsO4yDXtBv1zUU3mTpHeQ0d5.jpg',
      year: '1999',
      rating: 8.7,
      type: ContentType.movie,
      pluginId: 'com.probreflix',
      overview:
          'Um programador descobre que o mundo é uma simulação criada por máquinas inteligentes.',
    ),
  ];

  @override
  Future<List<ContentCategory>> getHome() async => [
    ContentCategory(
      name: '🚀 Sci-Fi & Universos Expandidos',
      items: probreList,
    ),
  ];

  @override
  Future<List<ContentItem>> search(String query, {int page = 1}) async =>
      probreList
          .where((i) => i.title.toLowerCase().contains(query.toLowerCase()))
          .toList();

  @override
  Future<ContentDetail> getDetail(String contentId) async {
    if (contentId.startsWith('tmdb_')) {
      final live = await TmdbService.getDetail(contentId, manifest.id);
      if (live != null) return live;
    }
    final match = probreList.where((i) => i.id == contentId);
    final item = match.isNotEmpty ? match.first : probreList.first;
    return ContentDetail(
      id: item.id,
      title: item.title,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl,
      overview: item.overview,
      year: item.year,
      rating: item.rating,
      type: item.type,
      pluginId: manifest.id,
      genres: const ['Ficção Científica', 'Ação'],
    );
  }

  @override
  Future<List<ContentItem>> getEpisodes(String seriesId, int season) async =>
      [];
}

/// 🎬 Plugin: Streamberry (Terror, Suspense & Mistério)
class StreamberryPlugin extends BaseScraperPlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'com.streamberry',
    name: 'Streamberry',
    version: 'v4',
    versionCode: 4,
    description: 'Terror, Suspense, Sobrenatural e Cinema Cult',
    author: 'Berry Labs',
    lang: 'pt-BR',
    iconUrl:
        'https://images.unsplash.com/photo-1518173946687-a4c8a383392e?w=100&auto=format&fit=crop&q=60',
    categories: ['movies', 'horror', 'thriller'],
    baseUrl: 'https://streamberry.xyz',
    entryPoint: 'streamberry.js',
    size: '23 KB',
    capabilities: PluginCapabilities(
      search: true,
      home: true,
      detail: true,
      streams: true,
    ),
  );

  static final List<ContentItem> horrorList = [
    const ContentItem(
      id: 'sb_1',
      title: 'Beetlejuice 2 (Os Fantasmas Se Divertem)',
      posterUrl:
          'https://image.tmdb.org/t/p/w500/kKgAkfAFT4v616t9iHlO7m3d7yW.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/1wP1phHo2CROOq5XA9TGg1x6Ynl.jpg',
      year: '2024',
      rating: 7.2,
      type: ContentType.movie,
      pluginId: 'com.streamberry',
      overview:
          'Três gerações da família Deetz retornam para casa e o portal para o pós-vida é reaberto acidentalmente.',
    ),
    const ContentItem(
      id: 'sb_2',
      title: 'Invocação do Mal',
      posterUrl: 'https://image.tmdb.org/t/p/w500/wVYREut692L7N1.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/kEl2t3OhXc3Zb9FBh1AuYzRTgZp.jpg',
      year: '2013',
      rating: 8.0,
      type: ContentType.movie,
      pluginId: 'com.streamberry',
      overview:
          'Os investigadores paranormais Ed e Lorraine Warren ajudam uma família aterrorizada por uma presença sombria.',
    ),
    const ContentItem(
      id: 'sb_3',
      title: 'Pânico VI (Scream VI)',
      posterUrl: 'https://image.tmdb.org/t/p/w500/wVYREut692L7.jpg',
      backdropUrl:
          'https://image.tmdb.org/t/p/original/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg',
      year: '2023',
      rating: 7.5,
      type: ContentType.movie,
      pluginId: 'com.streamberry',
      overview:
          'Os quatro sobreviventes dos assassinatos de Ghostface deixam Woodsboro para trás e começam um novo capítulo em Nova York.',
    ),
  ];

  @override
  Future<List<ContentCategory>> getHome() async => [
    ContentCategory(
      name: '👻 Terror & Suspense Sobrenatural',
      items: horrorList,
    ),
  ];

  @override
  Future<List<ContentItem>> search(String query, {int page = 1}) async =>
      horrorList
          .where((i) => i.title.toLowerCase().contains(query.toLowerCase()))
          .toList();

  @override
  Future<ContentDetail> getDetail(String contentId) async {
    if (contentId.startsWith('tmdb_')) {
      final live = await TmdbService.getDetail(contentId, manifest.id);
      if (live != null) return live;
    }
    final match = horrorList.where((i) => i.id == contentId);
    final item = match.isNotEmpty ? match.first : horrorList.first;
    return ContentDetail(
      id: item.id,
      title: item.title,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl,
      overview: item.overview,
      year: item.year,
      rating: item.rating,
      type: item.type,
      pluginId: manifest.id,
      genres: const ['Terror', 'Suspense', 'Mistério'],
    );
  }

  @override
  Future<List<ContentItem>> getEpisodes(String seriesId, int season) async =>
      [];
}

/// Filmes gratuitos cuja marcação de domínio público é publicada no
/// Internet Archive. Diferentemente dos embeds, estas são URLs MP4 diretas.
class PublicDomainPlugin implements PluginInterface {
  static const _pluginId = 'org.archive.publicdomain';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: _pluginId,
    name: 'Cinema Livre',
    version: 'v1',
    versionCode: 1,
    description: 'Filmes gratuitos e em domínio público',
    author: 'Internet Archive',
    lang: 'pt-BR',
    categories: ['movies', 'public-domain', 'free'],
    baseUrl: 'https://archive.org',
    capabilities: PluginCapabilities(
      search: true,
      home: true,
      detail: true,
      streams: true,
    ),
    entryPoint: 'native',
    size: 'Nativo',
  );

  static const movies = <ContentItem>[
    ContentItem(
      id: 'ia_his_girl_friday',
      title: 'Jejum de Amor',
      posterUrl: 'https://archive.org/services/img/his_girl_friday',
      year: '1940',
      rating: 7.8,
      type: ContentType.movie,
      pluginId: _pluginId,
      overview: 'Comédia romântica clássica com Cary Grant e Rosalind Russell.',
    ),
    ContentItem(
      id: 'ia_house_on_haunted_hill',
      title: 'A Casa dos Maus Espíritos',
      posterUrl: 'https://archive.org/services/img/house_on_haunted_hill_ipod',
      year: '1959',
      rating: 6.8,
      type: ContentType.movie,
      pluginId: _pluginId,
      overview:
          'Cinco pessoas recebem uma oferta para passar a noite em uma casa assombrada.',
    ),
    ContentItem(
      id: 'ia_jungle_book',
      title: 'O Livro da Selva',
      posterUrl: 'https://archive.org/services/img/JungleBook',
      year: '1942',
      rating: 6.7,
      type: ContentType.movie,
      pluginId: _pluginId,
      overview:
          'A aventura clássica de Mowgli, criado por lobos na selva indiana.',
    ),
    ContentItem(
      id: 'ia_sita_sings',
      title: 'Sita Sings the Blues',
      posterUrl: 'https://archive.org/services/img/Sita_Sings_the_Blues',
      year: '2008',
      rating: 7.6,
      type: ContentType.movie,
      pluginId: _pluginId,
      overview:
          'Animação independente distribuída sob dedicação ao domínio público.',
    ),
  ];

  static const _streams = <String, String>{
    'ia_his_girl_friday':
        'https://archive.org/download/his_girl_friday/his_girl_friday_512kb.mp4',
    'ia_house_on_haunted_hill':
        'https://archive.org/download/house_on_haunted_hill_ipod/house_on_haunted_hill_512kb.mp4',
    'ia_jungle_book':
        'https://archive.org/download/JungleBook/Jungle_Book_512kb.mp4',
    'ia_sita_sings':
        'https://archive.org/download/Sita_Sings_the_Blues/SITA_SINGS_MOVIE_ONLY.mp4',
  };

  @override
  Future<List<ContentCategory>> getHome() async => const [
    ContentCategory(name: 'Grátis e em Domínio Público', items: movies),
  ];

  @override
  Future<List<ContentItem>> search(String query, {int page = 1}) async {
    final normalized = query.toLowerCase().trim();
    return movies
        .where((item) => item.title.toLowerCase().contains(normalized))
        .toList();
  }

  @override
  Future<ContentDetail> getDetail(String contentId) async {
    final item = movies.firstWhere(
      (movie) => movie.id == contentId,
      orElse: () => movies.first,
    );
    return ContentDetail(
      id: item.id,
      title: item.title,
      posterUrl: item.posterUrl,
      overview: item.overview,
      year: item.year,
      rating: item.rating,
      duration: 'Filme completo',
      type: ContentType.movie,
      pluginId: _pluginId,
      genres: const ['Domínio público', 'Cinema clássico'],
    );
  }

  @override
  Future<List<StreamSource>> getStreams(
    String contentId, {
    int? season,
    int? episode,
  }) async {
    final url = _streams[contentId];
    if (url == null) return const [];
    return [
      StreamSource(
        url: url,
        quality: 'SD',
        server: 'Internet Archive',
        isDirect: true,
      ),
    ];
  }

  @override
  Future<List<ContentItem>> getEpisodes(String seriesId, int season) async =>
      const [];
}
