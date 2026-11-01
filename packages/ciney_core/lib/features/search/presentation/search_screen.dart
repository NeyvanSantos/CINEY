import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/localization/app_localization.dart';
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
  late final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'search-query',
    onKeyEvent: _handleSearchKey,
  );
  final ScrollController _resultsScroll = ScrollController(
    keepScrollOffset: false,
  );
  final Map<String, FocusNode> _resultFocusNodes = {};
  bool _focusResultsWhenReady = false;
  List<ContentItem> _results = [];
  bool _isSearching = false;
  String _selectedFilter = 'Todos';
  Timer? _debounceTimer;
  int _searchRequestId = 0;
  String? _searchError;

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
    _focusResultsWhenReady = false;
    _debounceTimer?.cancel();
    ++_searchRequestId;
    _searchError = null;
    if (query.trim().isEmpty) {
      _pruneResultFocusNodes(const []);
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
      _focusResultsWhenReady = false;
      _pruneResultFocusNodes(const []);
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
        });
      }
      return;
    }

    try {
      final results = await ref
          .read(pluginManagerProvider.notifier)
          .searchAll(cleanQuery);

      if (mounted && requestId == _searchRequestId) {
        _pruneResultFocusNodes(results);
        setState(() {
          _results = results;
          _searchError = null;
          _isSearching = false;
        });
        if (_focusResultsWhenReady) _focusFirstResult();
      }
    } catch (_) {
      if (mounted && requestId == _searchRequestId) {
        _focusResultsWhenReady = false;
        setState(() {
          _results = [];
          _isSearching = false;
          _searchError =
              'Não foi possível pesquisar. Verifique a conexão e tente novamente.';
        });
      }
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

  static String _resultKey(ContentItem item) =>
      '${item.pluginId}:${item.type.value}:${item.id}';

  FocusNode _resultNode(ContentItem item) => _resultFocusNodes.putIfAbsent(
    _resultKey(item),
    () => FocusNode(debugLabel: 'search-result-${_resultKey(item)}'),
  );

  void _pruneResultFocusNodes(List<ContentItem> results) {
    final retained = results.map(_resultKey).toSet();
    final removed = _resultFocusNodes.keys
        .where((key) => !retained.contains(key))
        .toList();
    for (final key in removed) {
      final node = _resultFocusNodes.remove(key)!;
      WidgetsBinding.instance.addPostFrameCallback((_) => node.dispose());
    }
  }

  KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
    if (!AppEnvironment.isTv ||
        event is KeyUpEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    if (_isSearching) {
      _focusResultsWhenReady = true;
      return KeyEventResult.handled;
    }
    if (_filterResults(_results, _selectedFilter).isEmpty) {
      return KeyEventResult.ignored;
    }
    _focusFirstResult();
    return KeyEventResult.handled;
  }

  void _focusFirstResult() {
    _focusResultsWhenReady = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isSearching || _searchController.text.trim().isEmpty) {
        return;
      }
      if (!TickerMode.valuesOf(context).enabled ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      final items = _filterResults(_results, _selectedFilter);
      if (items.isEmpty) return;
      if (_resultsScroll.hasClients) _resultsScroll.jumpTo(0);
      _resultNode(items.first).requestFocus();
    });
    // Keyboard input may not otherwise schedule a frame before requesting focus.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  KeyEventResult _handleResultKey(
    KeyEvent event,
    int index,
    int columns,
    List<ContentItem> items,
  ) {
    if (!AppEnvironment.isTv || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    int? next;
    if (key == LogicalKeyboardKey.arrowUp) {
      if (index < columns) {
        _searchFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      next = index - columns;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (index ~/ columns == (items.length - 1) ~/ columns) {
        return KeyEventResult.handled;
      }
      next = (index + columns).clamp(0, items.length - 1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (index % columns == columns - 1 || index + 1 == items.length) {
        return KeyEventResult.handled;
      }
      next = index + 1;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (index % columns == 0) return KeyEventResult.ignored;
      next = index - 1;
    }
    if (next == null) return KeyEventResult.ignored;
    _resultNode(items[next]).requestFocus();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _resultsScroll.dispose();
    for (final node in _resultFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredResults = _filterResults(_results, _selectedFilter);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.tr('search.title'),
          style: AppTypography.headlineLarge,
        ),
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
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  onSubmitted: _triggerSearchDirectly,
                  onEditingComplete: AppEnvironment.isTv
                      ? () {
                          _searchFocusNode.requestFocus();
                          SystemChannels.textInput.invokeMethod<void>(
                            'TextInput.hide',
                          );
                        }
                      : null,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: context.tr('search.hint'),
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

                    return Focus(
                      canRequestFocus: false,
                      onKeyEvent: (_, event) {
                        if (!AppEnvironment.isTv || event is KeyUpEvent) {
                          return KeyEventResult.ignored;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          return _handleSearchKey(_searchFocusNode, event);
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          _searchFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: FilterChip(
                        label: Text(
                          context.categoryLabel(filter),
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
                          if (_resultsScroll.hasClients) {
                            _resultsScroll.jumpTo(0);
                          }
                          setState(() => _selectedFilter = filter);
                        },
                      ),
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
    if (!_isSearching &&
        _searchError != null &&
        _searchController.text.trim().isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_searchError!),
            TextButton(
              onPressed: () => _triggerSearchDirectly(_searchController.text),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              context.tr('search.searching'),
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
                    context.tr('search.explore'),
                    style: AppTypography.headlineSmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('search.description'),
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
                  context.tr('search.trending'),
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
                context
                    .tr('search.no_results')
                    .replaceAll('{query}', _searchController.text),
                style: AppTypography.headlineSmall.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('search.no_results_help'),
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
                label: Text(context.tr('search.clear')),
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
            context
                .tr('search.results_count')
                .replaceAll('{count}', '${items.length}'),
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = AppEnvironment.isTv
                  ? (constraints.maxWidth / 170).floor().clamp(3, 8)
                  : 3;
              final ratio = AppEnvironment.isTv ? 2 / 3 : 0.65;
              final cardWidth =
                  (constraints.maxWidth - 32 - 12 * (columns - 1)) / columns;
              return GridView.builder(
                controller: _resultsScroll,
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: ratio,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];

                  return GradientPoster(
                    key: ValueKey(_resultKey(item)),
                    width: cardWidth,
                    height: cardWidth / ratio,
                    focusNode: AppEnvironment.isTv ? _resultNode(item) : null,
                    onKey: (_, event) =>
                        _handleResultKey(event, index, columns, items),
                    title: item.title,
                    posterUrl: item.posterUrl,
                    rating: item.rating,
                    year: item.year,
                    onTap: () {
                      context.push('/details/${item.id}/${item.pluginId}');
                    },
                  );
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
