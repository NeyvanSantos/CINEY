import 'package:ciney_core/plugin_engine/manager/plugin_manager.dart';
import 'package:ciney_core/plugin_engine/models/content_item.dart';
import 'package:ciney_core/plugin_engine/plugins/builtin_plugins.dart';
import 'package:flutter_test/flutter_test.dart';

class _Catalog extends PublicDomainPlugin {
  @override
  Future<List<ContentCategory>> getHome() async => [
    const ContentCategory(
      name: 'Homônimos',
      items: [
        ContentItem(
          id: 'one',
          title: 'Mesmo título',
          year: '1980',
          posterUrl: '',
          type: ContentType.movie,
          pluginId: 'test',
        ),
        ContentItem(
          id: 'two',
          title: 'Mesmo título',
          year: '2020',
          posterUrl: '',
          type: ContentType.movie,
          pluginId: 'test',
        ),
        ContentItem(
          id: 'three',
          title: 'Mesmo título',
          year: '2020',
          posterUrl: '',
          type: ContentType.series,
          pluginId: 'test',
        ),
      ],
    ),
  ];
}

void main() {
  test('remover todos os plugins também limpa o ativo', () {
    final manager = PluginManager();
    addTearDown(manager.dispose);
    for (final plugin in [...manager.state.installedPlugins]) {
      manager.removePlugin(plugin.manifest.id);
    }
    expect(manager.state.installedPlugins, isEmpty);
    expect(manager.state.activePlugin, isNull);
    expect(() => manager.setActivePluginById('missing'), returnsNormally);
  });

  test('Home preserva obras distintas com o mesmo título', () async {
    final manager = PluginManager();
    addTearDown(manager.dispose);
    for (final plugin in [...manager.state.installedPlugins]) {
      manager.removePlugin(plugin.manifest.id);
    }
    manager.installPlugin(_Catalog());
    final sections = await manager.getHomeSections();
    expect(sections.single.items.map((item) => item.id), [
      'one',
      'two',
      'three',
    ]);
  });

  test(
    'fontes próprias do catálogo público não dependem de busca TMDB',
    () async {
      final manager = PluginManager();
      addTearDown(manager.dispose);
      final sources = await manager.getStreams(
        'ia_sita_sings',
        'org.archive.publicdomain',
      );
      expect(sources, isNotEmpty);
      expect(Uri.parse(sources.single.url).host, 'archive.org');
      expect(sources.single.isEmbed, isFalse);
    },
  );
}
