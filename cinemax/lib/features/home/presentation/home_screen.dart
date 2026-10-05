import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/gradient_poster.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../plugin_engine/manager/plugin_manager.dart';
import '../../../plugin_engine/models/content_item.dart';
import '../../../plugin_engine/runtime/tmdb_service.dart';

class _ProceduralTheme {
  final String title;
  final String mediaType; // 'movie' ou 'tv'
  final String? withGenres;
  final String? withOriginalLanguage;
  final String? sortBy;
  final String? releaseDateLte;
  final int? voteCountGte;
  final ContentType? defaultType;

  const _ProceduralTheme({
    required this.title,
    required this.mediaType,
    this.withGenres,
    this.withOriginalLanguage,
    this.sortBy = 'popularity.desc',
    this.releaseDateLte,
    this.voteCountGte,
    this.defaultType,
  });
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<ContentCategory> _sections = [];
  bool _isLoading = true;
  String _selectedCategoryFilter = 'Todos';
  Future<void>? _homeLoadRequest;
  final PageController _heroController = PageController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _categoryFilters = [
    'Todos',
    'Filmes',
    'Séries',
    'Animes',
    'Doramas',
  ];

  // Feed procedural infinito
  final List<ContentCategory> _proceduralSections = [];
  final Set<String> _displayedItemIds = {};
  int _themeIndex = 0;
  int _themePage = 1;
  bool _isLoadingProcedural = false;

  // Catálogo procedural infinito por temas TMDB
  static const List<_ProceduralTheme> _allThemes = [
    _ProceduralTheme(title: 'Filmes de Ação & Pura Adrenalina', mediaType: 'movie', withGenres: '28'),
    _ProceduralTheme(title: 'Séries Mais Assistidas', mediaType: 'tv', sortBy: 'popularity.desc'),
    _ProceduralTheme(title: 'Comédias Imperdíveis', mediaType: 'movie', withGenres: '35'),
    _ProceduralTheme(title: 'Ficção Científica & Futuro', mediaType: 'movie', withGenres: '878'),
    _ProceduralTheme(title: 'Animes em Destaque', mediaType: 'tv', withGenres: '16', withOriginalLanguage: 'ja', defaultType: ContentType.anime),
    _ProceduralTheme(title: 'Suspense & Mistério', mediaType: 'movie', withGenres: '53,9648'),
    _ProceduralTheme(title: 'Doramas Coreanos Favoritos', mediaType: 'tv', withOriginalLanguage: 'ko', defaultType: ContentType.dorama),
    _ProceduralTheme(title: 'Aventura & Fantasia', mediaType: 'movie', withGenres: '12,14'),
    _ProceduralTheme(title: 'Terror & Sobrenatural', mediaType: 'movie', withGenres: '27'),
    _ProceduralTheme(title: 'Séries Policiais & Investigação', mediaType: 'tv', withGenres: '80'),
    _ProceduralTheme(title: 'Animações para Toda Família', mediaType: 'movie', withGenres: '16,10751'),
    _ProceduralTheme(title: 'Dramas Aclamados pela Crítica', mediaType: 'movie', withGenres: '18', sortBy: 'vote_average.desc', voteCountGte: 800),
    _ProceduralTheme(title: 'Séries de Mistério & Ficção', mediaType: 'tv', withGenres: '10765,9648'),
    _ProceduralTheme(title: 'Romances Apaixonantes', mediaType: 'movie', withGenres: '10749'),
    _ProceduralTheme(title: 'Documentários & Histórias Reais', mediaType: 'movie', withGenres: '99'),
    _ProceduralTheme(title: 'Clássicos Inesquecíveis', mediaType: 'movie', releaseDateLte: '2005-01-01', sortBy: 'vote_average.desc', voteCountGte: 1500),
  ];

  static const List<_ProceduralTheme> _movieThemes = [
    _ProceduralTheme(title: 'Filmes de Ação Explosiva', mediaType: 'movie', withGenres: '28'),
    _ProceduralTheme(title: 'Comédias Divertidas', mediaType: 'movie', withGenres: '35'),
    _ProceduralTheme(title: 'Ficção Científica & Espaço', mediaType: 'movie', withGenres: '878'),
    _ProceduralTheme(title: 'Suspense Eletrizante', mediaType: 'movie', withGenres: '53'),
    _ProceduralTheme(title: 'Terror de Arrepiar', mediaType: 'movie', withGenres: '27'),
    _ProceduralTheme(title: 'Aventura & Exploração', mediaType: 'movie', withGenres: '12'),
    _ProceduralTheme(title: 'Mundos Mágicos & Fantasia', mediaType: 'movie', withGenres: '14'),
    _ProceduralTheme(title: 'Animações Cinematográficas', mediaType: 'movie', withGenres: '16,10751'),
    _ProceduralTheme(title: 'Dramas Profundos & Emocionantes', mediaType: 'movie', withGenres: '18'),
    _ProceduralTheme(title: 'Romances Apaixonados', mediaType: 'movie', withGenres: '10749'),
    _ProceduralTheme(title: 'Guerra & Batalhas Épicas', mediaType: 'movie', withGenres: '10752'),
    _ProceduralTheme(title: 'Filmes Mais Bem Avaliados', mediaType: 'movie', sortBy: 'vote_average.desc', voteCountGte: 1000),
    _ProceduralTheme(title: 'Clássicos de Ouro do Cinema', mediaType: 'movie', releaseDateLte: '2005-01-01', sortBy: 'vote_average.desc', voteCountGte: 1500),
  ];

  static const List<_ProceduralTheme> _seriesThemes = [
    _ProceduralTheme(title: 'Séries do Momento', mediaType: 'tv', sortBy: 'popularity.desc'),
    _ProceduralTheme(title: 'Séries de Ação & Aventura', mediaType: 'tv', withGenres: '10759'),
    _ProceduralTheme(title: 'Dramas Envolventes & Premiados', mediaType: 'tv', withGenres: '18'),
    _ProceduralTheme(title: 'Mistério & Ficção Científica', mediaType: 'tv', withGenres: '10765,9648'),
    _ProceduralTheme(title: 'Comédias & Sitcoms', mediaType: 'tv', withGenres: '35'),
    _ProceduralTheme(title: 'Séries Policiais & Crimes Reais', mediaType: 'tv', withGenres: '80'),
    _ProceduralTheme(title: 'Séries Documentais', mediaType: 'tv', withGenres: '99'),
    _ProceduralTheme(title: 'Séries Mais Bem Avaliadas', mediaType: 'tv', sortBy: 'vote_average.desc', voteCountGte: 500),
  ];

  static const List<_ProceduralTheme> _animeThemes = [
    _ProceduralTheme(title: 'Animes Populares no Japão', mediaType: 'tv', withGenres: '16', withOriginalLanguage: 'ja', defaultType: ContentType.anime),
    _ProceduralTheme(title: 'Animes de Ação & Batalhas Épicas', mediaType: 'tv', withGenres: '16,10759', withOriginalLanguage: 'ja', defaultType: ContentType.anime),
    _ProceduralTheme(title: 'Animes de Fantasia & Isekai', mediaType: 'tv', withGenres: '16,10765', withOriginalLanguage: 'ja', defaultType: ContentType.anime),
    _ProceduralTheme(title: 'Comédias & Vida Cotidiana em Anime', mediaType: 'tv', withGenres: '16,35', withOriginalLanguage: 'ja', defaultType: ContentType.anime),
    _ProceduralTheme(title: 'Filmes em Anime', mediaType: 'movie', withGenres: '16', withOriginalLanguage: 'ja', defaultType: ContentType.anime),
    _ProceduralTheme(title: 'Animes Mais Bem Avaliados', mediaType: 'tv', withGenres: '16', withOriginalLanguage: 'ja', sortBy: 'vote_average.desc', voteCountGte: 100, defaultType: ContentType.anime),
  ];

  static const List<_ProceduralTheme> _doramaThemes = [
    _ProceduralTheme(title: 'K-Dramas Românticos Mais Amados', mediaType: 'tv', withOriginalLanguage: 'ko', defaultType: ContentType.dorama),
    _ProceduralTheme(title: 'Dramas Coreanos Emocionantes', mediaType: 'tv', withGenres: '18', withOriginalLanguage: 'ko', defaultType: ContentType.dorama),
    _ProceduralTheme(title: 'Comédias Românticas Coreanas', mediaType: 'tv', withGenres: '35', withOriginalLanguage: 'ko', defaultType: ContentType.dorama),
    _ProceduralTheme(title: 'Doramas de Suspense & Investigação', mediaType: 'tv', withGenres: '80,9648', withOriginalLanguage: 'ko', defaultType: ContentType.dorama),
    _ProceduralTheme(title: 'Doramas Populares do Momento', mediaType: 'tv', withOriginalLanguage: 'ko', sortBy: 'popularity.desc', defaultType: ContentType.dorama),
    _ProceduralTheme(title: 'Doramas Aclamados pelo Público', mediaType: 'tv', withOriginalLanguage: 'ko', sortBy: 'vote_average.desc', voteCountGte: 50, defaultType: ContentType.dorama),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHomeData();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 600) {
      _loadNextProceduralBatch(count: 2);
    }
  }

  List<_ProceduralTheme> _getActiveThemeList() {
    switch (_selectedCategoryFilter) {
      case 'Filmes':
        return _movieThemes;
      case 'Séries':
        return _seriesThemes;
      case 'Animes':
        return _animeThemes;
      case 'Doramas':
        return _doramaThemes;
      default:
        return _allThemes;
    }
  }

  Future<void> _loadNextProceduralBatch({int count = 2}) async {
    if (_isLoadingProcedural) return;
    _isLoadingProcedural = true;
    if (mounted) setState(() {});

    final themes = _getActiveThemeList();
    if (themes.isEmpty) {
      _isLoadingProcedural = false;
      if (mounted) setState(() {});
      return;
    }

    final newSections = <ContentCategory>[];

    for (int i = 0; i < count; i++) {
      if (_themeIndex >= themes.length) {
        _themeIndex = 0;
        _themePage++;
      }

      final theme = themes[_themeIndex];
      _themeIndex++;

      try {
        final items = await TmdbService.getDiscoverContent(
          mediaType: theme.mediaType,
          withGenres: theme.withGenres,
          withOriginalLanguage: theme.withOriginalLanguage,
          sortBy: theme.sortBy,
          releaseDateLte: theme.releaseDateLte,
          voteCountGte: theme.voteCountGte,
          page: _themePage,
          defaultType: theme.defaultType,
        );

        final uniqueItems = <ContentItem>[];
        for (final item in items) {
          final key = item.id;
          if (_displayedItemIds.add(key)) {
            uniqueItems.add(item);
          }
        }

        if (uniqueItems.isNotEmpty) {
          final sectionTitle = _themePage > 1
              ? '${theme.title} • Lote $_themePage'
              : theme.title;
          newSections.add(ContentCategory(
            name: sectionTitle,
            items: uniqueItems,
          ));
        }
      } catch (_) {
        // Ignora erros pontuais de conexão
      }
    }

    if (mounted) {
      setState(() {
        _proceduralSections.addAll(newSections);
        _isLoadingProcedural = false;
      });
    }
  }

  Future<void> _loadHomeData() {
    final inFlight = _homeLoadRequest;
    if (inFlight != null) return inFlight;
    final request = _loadHomeDataInternal();
    _homeLoadRequest = request;
    return request.whenComplete(() {
      if (identical(_homeLoadRequest, request)) _homeLoadRequest = null;
    });
  }

  Future<void> _loadHomeDataInternal() async {
    setState(() => _isLoading = true);
    final sections = await ref
        .read(pluginManagerProvider.notifier)
        .getAllHomeSections();
    if (mounted) {
      setState(() {
        _sections = sections;
        _isLoading = false;
        _themeIndex = 0;
        _themePage = 1;
        _displayedItemIds.clear();
        _proceduralSections.clear();
      });

      // Registra itens do topo para não repetir no procedural
      for (final s in _filteredBaseSections) {
        for (final item in s.items) {
          _displayedItemIds.add(item.id);
        }
      }

      // Inicia imediatamente o primeiro lote de seções procedurais
      _loadNextProceduralBatch(count: 3);
    }
  }

  void _onCategoryFilterChanged(String category) {
    if (_selectedCategoryFilter == category) return;
    setState(() {
      _selectedCategoryFilter = category;
      _themeIndex = 0;
      _themePage = 1;
      _displayedItemIds.clear();
      _proceduralSections.clear();
    });

    for (final s in _filteredBaseSections) {
      for (final item in s.items) {
        _displayedItemIds.add(item.id);
      }
    }

    _loadNextProceduralBatch(count: 3);
  }

  /// Seções fixas do topo: Lançamentos e Em Alta em destaque prioritário
  List<ContentCategory> get _filteredBaseSections {
    final source = _sections
        .where(
          (section) =>
              !section.name.toLowerCase().contains('domínio público') &&
              !section.name.toLowerCase().contains('dominio publico'),
        )
        .toList();
    final items = _uniqueItems(source.expand((section) => section.items));
    final launches = [...items]
      ..sort((a, b) => (b.year ?? '').compareTo(a.year ?? ''));
    final trending = [...items]
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));

    if (_selectedCategoryFilter == 'Todos') {
      return [
        if (launches.isNotEmpty)
          ContentCategory(name: 'Lançamentos', items: launches.take(18).toList()),
        if (trending.isNotEmpty)
          ContentCategory(name: 'Em Alta', items: trending.take(18).toList()),
      ];
    }

    if (_selectedCategoryFilter == 'Filmes') {
      final movieLaunches = launches.where((i) => i.type == ContentType.movie).take(18).toList();
      final movieTrending = trending.where((i) => i.type == ContentType.movie).take(18).toList();
      return [
        if (movieLaunches.isNotEmpty)
          ContentCategory(name: 'Lançamentos em Filmes', items: movieLaunches),
        if (movieTrending.isNotEmpty)
          ContentCategory(name: 'Filmes em Alta', items: movieTrending),
      ];
    }

    if (_selectedCategoryFilter == 'Séries') {
      final seriesLaunches = launches.where((i) => i.type == ContentType.series).take(18).toList();
      final seriesTrending = trending.where((i) => i.type == ContentType.series).take(18).toList();
      return [
        if (seriesLaunches.isNotEmpty)
          ContentCategory(name: 'Lançamentos em Séries', items: seriesLaunches),
        if (seriesTrending.isNotEmpty)
          ContentCategory(name: 'Séries em Alta', items: seriesTrending),
      ];
    }

    if (_selectedCategoryFilter == 'Animes') {
      final animes = items.where((i) => i.type == ContentType.anime).take(18).toList();
      return [
        if (animes.isNotEmpty)
          ContentCategory(name: 'Animes em Destaque', items: animes),
      ];
    }

    if (_selectedCategoryFilter == 'Doramas') {
      final doramas = items.where((i) => i.type == ContentType.dorama).take(18).toList();
      return [
        if (doramas.isNotEmpty)
          ContentCategory(name: 'Doramas em Destaque', items: doramas),
      ];
    }

    return [];
  }

  List<ContentCategory> get _allVisibleSections {
    return [..._filteredBaseSections, ..._proceduralSections];
  }

  List<ContentItem> _uniqueItems(Iterable<ContentItem> source) {
    final seen = <String>{};
    return source
        .where((item) => seen.add('${item.pluginId}:${item.id}'))
        .toList();
  }

  List<ContentItem> get _heroItems {
    final source = _sections
        .where(
          (section) =>
              !section.name.toLowerCase().contains('domínio público') &&
              !section.name.toLowerCase().contains('dominio publico'),
        )
        .toList();
    final items = _uniqueItems(source.expand((section) => section.items));
    if (items.isEmpty) return const [];
    return items.take(6).toList();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = _allVisibleSections;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar transparente com logo CiNey
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background.withValues(alpha: 0.85),
              elevation: 0,
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RichText(
                    text: TextSpan(
                      text: 'CI',
                      style: AppTypography.headlineMedium.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                      children: const [
                        TextSpan(
                          text: 'NEY',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: Colors.white),
                  onPressed: () => context.go('/search'),
                ),
              ],
            ),

            // Filtros rápidos por Categoria (Todos, Filmes, Séries, Animes, Doramas)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  itemCount: _categoryFilters.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = _categoryFilters[index];
                    final isSelected = _selectedCategoryFilter == category;

                    return ChoiceChip(
                      label: Text(
                        category,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceLight,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.glassBorder,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          _onCategoryFilterChanged(category);
                        }
                      },
                    );
                  },
                ),
              ),
            ),

            SliverToBoxAdapter(child: _buildHeroCarousel()),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Seções de Conteúdo Dinâmicas, Lançamentos/Em Alta no topo e Procedural Infinito
            if (_isLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: ShimmerLoading.carousel(),
                  ),
                  childCount: 3,
                ),
              )
            else if (sections.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.movie_filter_rounded,
                          size: 48,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhum conteúdo disponível nesta categoria',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadHomeData,
                          child: const Text('Recarregar Catálogo'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final section = sections[index];
                  return _buildCarouselSection(section);
                }, childCount: sections.length),
              ),

            // Indicador sutil de carregamento procedural sob demanda
            if (_isLoadingProcedural)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Descobrindo novos títulos...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCarousel() {
    final heroItems = _heroItems;
    if (heroItems.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 220,
        child: PageView.builder(
          controller: _heroController,
          itemCount: heroItems.length,
          itemBuilder: (context, index) => _buildHeroItem(heroItems[index]),
        ),
      ),
    );
  }

  Widget _buildHeroItem(ContentItem item) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: item.backdropUrl?.isNotEmpty == true
                  ? item.backdropUrl!
                  : item.posterUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const ColoredBox(
                color: AppColors.surface,
                child: Icon(
                  Icons.movie_creation_outlined,
                  color: AppColors.textTertiary,
                  size: 48,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.headlineLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.rating?.toStringAsFixed(1) ?? 'N/A'}  •  ${item.year ?? item.type.displayName}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => context.push(
                          '/player/${item.id}/${item.pluginId}?title=${Uri.encodeComponent(item.title)}',
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Assistir'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => context.push(_detailsRoute(item)),
                        child: const Text('Detalhes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselSection(ContentCategory category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    category.name,
                    style: AppTypography.headlineMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(
                    '/section?name=${Uri.encodeQueryComponent(category.name)}',
                    extra: category.items,
                  ),
                  child: const Text(
                    'Ver todos',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: category.items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = category.items[index];

                return GradientPoster(
                  title: item.title,
                  posterUrl: item.posterUrl,
                  rating: item.rating,
                  year: item.year,
                  onTap: () {
                    context.push(_detailsRoute(item));
                  },
                );
              },
            ),
          ),
        ],
      ),
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
}
