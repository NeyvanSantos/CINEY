import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/gradient_poster.dart';
import '../../../plugin_engine/manager/plugin_manager.dart';
import '../../../plugin_engine/models/content_item.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ContentItem> _results = [];
  bool _isSearching = false;
  String _selectedFilter = 'Todos';
  Timer? _debounceTimer;
  int _searchRequestId = 0;

  final List<String> _filters = [
    'Todos',
    'Filmes',
    'Séries',
    'Animes',
    'Doramas',
  ];

  final List<String> _popularSuggestions = [
    'Thor',
    'Deadpool & Wolverine',
    'Duna: Parte 2',
    'Vingadores',
    'Gladiador II',
    'Stranger Things',
    'Loki',
    'One Piece',
    'Batman',
    'Interestelar',
    'Oppenheimer',
    'Demon Slayer',
  ];

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final requestId = ++_searchRequestId;
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
        });
      }
      return;
    }

    final results = await ref
        .read(pluginManagerProvider.notifier)
        .searchAll(cleanQuery);

    if (mounted && requestId == _searchRequestId) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  void _triggerSearchDirectly(String term) {
    _debounceTimer?.cancel();
    _searchController.text = term;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: term.length),
    );
    setState(() => _isSearching = true);
    _performSearch(term);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredResults = _filterResults(_results, _selectedFilter);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Buscar', style: AppTypography.headlineLarge),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Barra de pesquisa com debounce
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSubmitted: _triggerSearchDirectly,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar filmes, séries, animes...',
                    prefixIcon: const Icon(
                      Iconsax.search_normal,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () {
                              _debounceTimer?.cancel();
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // Chips de filtros rápidos
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  itemCount: _filters.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;

                    return FilterChip(
                      label: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
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
                      onSelected: (selected) {
                        setState(() => _selectedFilter = filter);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(filteredResults),
    );
  }

  Widget _buildBody(List<ContentItem> items) {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Buscando em todo o catálogo...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Icon(
                    Iconsax.search_favorite,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Explore o Catálogo CiNey',
                    style: AppTypography.headlineSmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Milhões de filmes, séries e animes do TMDB e extensões',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sugestões em Alta',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _popularSuggestions.map((term) {
                return ActionChip(
                  label: Text(
                    term,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  backgroundColor: AppColors.surfaceLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  onPressed: () => _triggerSearchDirectly(term),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.sentiment_dissatisfied_rounded,
                size: 64,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhum resultado para "${_searchController.text}"',
                style: AppTypography.headlineSmall.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tente buscar pelo nome original, simplificar os termos ou verificar a ortografia.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _performSearch('');
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Limpar Pesquisa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceLight,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 4,
          ),
          child: Text(
            '${items.length} título(s) encontrado(s)',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: (MediaQuery.sizeOf(context).width / 250)
                  .floor()
                  .clamp(3, 7)
                  .toInt(),
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              return GradientPoster(
                title: item.title,
                posterUrl: item.posterUrl,
                rating: item.rating,
                year: item.year,
                onTap: () {
                  context.push('/details/${item.id}/${item.pluginId}');
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<ContentItem> _filterResults(List<ContentItem> list, String filter) {
    if (filter == 'Todos') return list;
    if (filter == 'Filmes') {
      return list.where((i) => i.type == ContentType.movie).toList();
    }
    if (filter == 'Séries') {
      return list.where((i) => i.type == ContentType.series).toList();
    }
    if (filter == 'Animes') {
      return list.where((i) => i.type == ContentType.anime).toList();
    }
    if (filter == 'Doramas') {
      return list.where((i) => i.type == ContentType.dorama).toList();
    }
    return list;
  }
}
