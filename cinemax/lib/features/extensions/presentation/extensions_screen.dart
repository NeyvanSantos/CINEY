import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../plugin_engine/manager/plugin_manager.dart';
import '../../../plugin_engine/manager/repository_manager.dart';
import '../../../plugin_engine/models/plugin_manifest.dart';

class ExtensionsScreen extends ConsumerStatefulWidget {
  const ExtensionsScreen({super.key});

  @override
  ConsumerState<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends ConsumerState<ExtensionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final TextEditingController _repoUrlController = TextEditingController();

  final List<String> _categories = [
    'Todos',
    'Filmes',
    'Séries',
    'Anime',
    'Dramas Asiáticos',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _repoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repoState = ref.watch(repositoryManagerProvider);
    final pluginState = ref.watch(pluginManagerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Extensões', style: AppTypography.headlineLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar Repositórios',
            onPressed: () {
              ref
                  .read(repositoryManagerProvider.notifier)
                  .fetchRepositoryPlugins(repoState.activeRepoUrl);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_link_rounded),
            tooltip: 'Adicionar Repositório por URL',
            onPressed: _showAddRepositoryDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Barra de pesquisa
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Filtrar extensões...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),

              // Abas de categorias
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: _categories.map((c) => Tab(text: c)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Banner de repositório ativo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surfaceLight,
            child: Row(
              children: [
                const Icon(Icons.code_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TLN+ Plugins (Repositório Oficial)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        repoState.activeRepoUrl,
                        style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${repoState.availablePlugins.length} plugins',
                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Lista de plugins disponíveis
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((category) {
                final filtered = _filterPlugins(repoState.availablePlugins, category, _searchQuery);

                if (repoState.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.extension_off_rounded, size: 48, color: AppColors.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhuma extensão encontrada',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final manifest = filtered[index];
                    final isInstalled = pluginState.installedPlugins.any((p) => p.manifest.id == manifest.id);

                    return _buildPluginTile(manifest, isInstalled);
                  },
                );
              }).toList(),
            ),
          ),

          // Botão inferior para Adicionar Repositório Padrão
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.read(repositoryManagerProvider.notifier).addDefaultRepository();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Repositório padrão sincronizado com sucesso!'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  label: const Text(
                    'Adicionar repositório Padrão',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPluginTile(PluginManifest manifest, bool isInstalled) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 14,
      child: Row(
        children: [
          // Ícone estilizado do plugin
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _getCategoryColor(manifest.categories.first).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getCategoryColor(manifest.categories.first).withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                manifest.name.substring(0, manifest.name.length >= 2 ? 2 : 1).toUpperCase(),
                style: TextStyle(
                  color: _getCategoryColor(manifest.categories.first),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Informações do plugin (Nome, Idioma, Versão, Tamanho KB, Descrição)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      manifest.name,
                      style: AppTypography.pluginName,
                    ),
                    const SizedBox(width: 6),
                    if (manifest.description.contains('Desativado'))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Desativado',
                          style: TextStyle(fontSize: 9, color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(manifest.langFlag, style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text(
                      '${manifest.langLabel} ${manifest.version} ${manifest.size ?? "25 KB"}',
                      style: AppTypography.pluginDescription,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  manifest.description,
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Ação: Lixeira para excluir ou Download para instalar
          IconButton(
            icon: Icon(
              isInstalled ? Icons.delete_outline_rounded : Icons.download_rounded,
              color: isInstalled ? Colors.white70 : AppColors.primary,
              size: 22,
            ),
            tooltip: isInstalled ? 'Desinstalar' : 'Instalar',
            onPressed: () {
              if (isInstalled) {
                ref.read(pluginManagerProvider.notifier).removePlugin(manifest.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Plugin ${manifest.name} removido.'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Plugin ${manifest.name} ativado com sucesso!'),
                    backgroundColor: AppColors.primary,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'anime':
        return AppColors.categoryAnime;
      case 'doramas':
      case 'dorama':
        return AppColors.categoryDoramas;
      case 'series':
        return AppColors.categorySeries;
      default:
        return AppColors.categoryMovies;
    }
  }

  List<PluginManifest> _filterPlugins(List<PluginManifest> plugins, String category, String query) {
    return plugins.where((p) {
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query);

      if (!matchesQuery) return false;

      if (category == 'Todos') return true;
      if (category == 'Filmes') return p.categories.contains('movies');
      if (category == 'Séries') return p.categories.contains('series');
      if (category == 'Anime') return p.categories.contains('anime');
      if (category == 'Dramas Asiáticos') return p.categories.contains('doramas') || p.categories.contains('dorama');

      return true;
    }).toList();
  }

  void _showAddRepositoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Repositório'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Insira a URL do arquivo repo.json com a lista de extensões:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _repoUrlController,
              decoration: const InputDecoration(
                hintText: 'https://exemplo.com/repo.json',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = _repoUrlController.text.trim();
              if (url.isNotEmpty) {
                ref.read(repositoryManagerProvider.notifier).addRepository(url);
                Navigator.pop(context);
                _repoUrlController.clear();
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }
}
