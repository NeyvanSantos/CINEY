import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/gradient_poster.dart';
import '../../../plugin_engine/manager/plugin_manager.dart';
import '../../../plugin_engine/models/content_item.dart';

class CatalogSectionScreen extends ConsumerWidget {
  final String sectionName;
  final List<ContentItem>? initialItems;

  const CatalogSectionScreen({
    super.key,
    required this.sectionName,
    this.initialItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialItems != null && initialItems!.isNotEmpty) {
      final items = _uniqueItems(initialItems!);
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(sectionName, style: AppTypography.headlineMedium),
          backgroundColor: AppColors.background,
        ),
        body: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 170,
            childAspectRatio: 0.66,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GradientPoster(
              title: item.title,
              posterUrl: item.posterUrl,
              rating: item.rating,
              year: item.year,
              onTap: () => context.push(_detailsRoute(item)),
            );
          },
        ),
      );
    }

    return FutureBuilder<List<ContentCategory>>(
      future: ref.read(pluginManagerProvider.notifier).getAllHomeSections(),
      builder: (context, snapshot) {
        final sections = snapshot.data ?? const <ContentCategory>[];
        final section = _resolveSection(sections);
        final items = _uniqueItems(section.items);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(sectionName, style: AppTypography.headlineMedium),
            backgroundColor: AppColors.background,
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : items.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum título disponível nesta categoria.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 170,
                    childAspectRatio: 0.66,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return GradientPoster(
                      title: item.title,
                      posterUrl: item.posterUrl,
                      rating: item.rating,
                      year: item.year,
                      onTap: () => context.push(_detailsRoute(item)),
                    );
                  },
                ),
        );
      },
    );
  }

  List<ContentItem> _uniqueItems(List<ContentItem> source) {
    final seen = <String>{};
    return source
        .where((item) => seen.add('${item.pluginId}:${item.id}'))
        .toList();
  }

  ContentCategory _resolveSection(List<ContentCategory> source) {
    final direct = source.where((item) => item.name == sectionName);
    if (direct.isNotEmpty) return direct.first;

    final usable = source.where((item) {
      final name = item.name.toLowerCase();
      return !name.contains('domínio público') &&
          !name.contains('dominio publico');
    });
    final all = _uniqueItems(usable.expand((item) => item.items).toList());
    if (sectionName == 'Destaques') {
      return ContentCategory(name: sectionName, items: all.take(18).toList());
    }
    if (sectionName == 'Lançamentos') {
      final items = [...all]
        ..sort((a, b) => (b.year ?? '').compareTo(a.year ?? ''));
      return ContentCategory(name: sectionName, items: items.take(18).toList());
    }
    if (sectionName == 'Mais assistidos') {
      final items = [...all]
        ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      return ContentCategory(name: sectionName, items: items.take(18).toList());
    }
    if (sectionName == 'Filmes de Ação') {
      final items = usable
          .where((item) {
            final name = item.name.toLowerCase();
            return name.contains('ação') ||
                name.contains('acao') ||
                name.contains('blockbuster');
          })
          .expand((item) => item.items)
          .toList();
      return ContentCategory(
        name: sectionName,
        items: _uniqueItems(items).take(18).toList(),
      );
    }
    return ContentCategory(name: sectionName, items: const []);
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
