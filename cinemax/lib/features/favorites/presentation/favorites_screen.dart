import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_poster.dart';
import '../../auth/services/account_repository.dart';
import '../services/favorites_repository.dart';
import 'favorite_button.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(favoritesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountUserProvider);
    final favorites = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Meus favoritos', style: AppTypography.headlineMedium),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(favoritesProvider),
            tooltip: 'Atualizar favoritos',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: account.isLoading
          ? const Center(child: CircularProgressIndicator())
          : account.valueOrNull == null
          ? Center(
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Entre para salvar seus favoritos.'),
                    TextButton(
                      onPressed: () => context.push('/auth'),
                      child: const Text('Entrar'),
                    ),
                  ],
                ),
              ),
            )
          : favorites.when(
              skipLoadingOnReload: false,
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Não foi possível carregar seus favoritos.'),
                      TextButton(
                        onPressed: () => ref.invalidate(favoritesProvider),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: GlassCard(
                          child: Text(
                            'Sua lista está vazia. Toque no coração de um filme ou série para salvar aqui.',
                          ),
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 210,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Stack(
                          key: ValueKey((item.pluginId, item.type, item.id)),
                          fit: StackFit.expand,
                          children: [
                            GradientPoster(
                              title: item.title,
                              posterUrl: item.posterUrl,
                              type: item.type.value,
                              onTap: () => context.push(
                                Uri(
                                  pathSegments: [
                                    '',
                                    'details',
                                    item.id,
                                    item.pluginId,
                                  ],
                                  queryParameters: {
                                    'title': item.title,
                                    'poster': item.posterUrl,
                                    'type': item.type.value,
                                  },
                                ).toString(),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: FavoriteButton(item: item),
                            ),
                          ],
                        );
                      },
                    ),
            ),
    );
  }
}
