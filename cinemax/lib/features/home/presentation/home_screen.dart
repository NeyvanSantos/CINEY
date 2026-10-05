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

  final List<String> _categoryFilters = [
    'Todos',
    'Filmes',
    'Séries',
    'Animes',
    'Doramas',
  ];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
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
      });
    }
  }

  List<ContentCategory> get _filteredSections {
    final sections = _organizedSections;
    if (_selectedCategoryFilter == 'Todos') return sections;

    if (_selectedCategoryFilter == 'Filmes') {
      return sections
          .where((s) => s.name.contains('Filmes') || s.name.contains('Em Alta'))
          .map(
            (s) => ContentCategory(
              name: s.name,
              items: s.items.where((i) => i.type == ContentType.movie).toList(),
            ),
          )
          .where((s) => s.items.isNotEmpty)
          .toList();
    }

    if (_selectedCategoryFilter == 'Séries') {
      return sections
          .where((s) => s.name.contains('Séries') || s.name.contains('Em Alta'))
          .map(
            (s) => ContentCategory(
              name: s.name,
              items: s.items
                  .where((i) => i.type == ContentType.series)
                  .toList(),
            ),
          )
          .where((s) => s.items.isNotEmpty)
          .toList();
    }

    if (_selectedCategoryFilter == 'Animes') {
      return sections.where((s) => s.name.contains('Anime')).toList();
    }

    if (_selectedCategoryFilter == 'Doramas') {
      return sections
          .where((s) => s.name.contains('Dorama') || s.name.contains('K-Drama'))
          .toList();
    }

    return _sections;
  }

  List<ContentCategory> get _organizedSections {
    final source = _sections
        .where(
          (section) =>
              !section.name.toLowerCase().contains('domínio público') &&
              !section.name.toLowerCase().contains('dominio publico'),
        )
        .toList();
    final items = _uniqueItems(source.expand((section) => section.items));
    final highlights = _uniqueItems(
      source.expand((section) => section.items).take(18),
    );
    final launches = [...items]
      ..sort((a, b) => (b.year ?? '').compareTo(a.year ?? ''));
    final mostWatched = [...items]
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    final actionSource = source
        .where(
          (section) =>
              section.name.toLowerCase().contains('ação') ||
              section.name.toLowerCase().contains('acao') ||
              section.name.toLowerCase().contains('blockbuster'),
        )
        .expand((section) => section.items);

    return [
      if (highlights.isNotEmpty)
        ContentCategory(name: 'Destaques', items: highlights),
      if (launches.isNotEmpty)
        ContentCategory(name: 'Lançamentos', items: launches.take(18).toList()),
      if (mostWatched.isNotEmpty)
        ContentCategory(
          name: 'Mais assistidos',
          items: mostWatched.take(18).toList(),
        ),
      if (actionSource.isNotEmpty)
        ContentCategory(
          name: 'Filmes de Ação',
          items: _uniqueItems(actionSource).take(18).toList(),
        ),
    ];
  }

  List<ContentItem> _uniqueItems(Iterable<ContentItem> source) {
    final seen = <String>{};
    return source
        .where((item) => seen.add('${item.pluginId}:${item.id}'))
        .toList();
  }

  List<ContentItem> get _heroItems => _organizedSections
      .firstWhere(
        (section) => section.name == 'Destaques',
        orElse: () => const ContentCategory(name: 'Destaques', items: []),
      )
      .items
      .take(6)
      .toList();

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSections;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
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
                          setState(() => _selectedCategoryFilter = category);
                        }
                      },
                    );
                  },
                ),
              ),
            ),

            SliverToBoxAdapter(child: _buildHeroCarousel()),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Seções de Conteúdo Dinâmicas e Unificadas
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
            else if (filtered.isEmpty)
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
                  final section = filtered[index];
                  return _buildCarouselSection(section);
                }, childCount: filtered.length),
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
