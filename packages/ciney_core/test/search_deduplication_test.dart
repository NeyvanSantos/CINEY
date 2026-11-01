import 'package:ciney_core/plugin_engine/manager/plugin_manager.dart';
import 'package:ciney_core/plugin_engine/models/content_item.dart';
import 'package:ciney_core/plugin_engine/models/plugin_manifest.dart';
import 'package:ciney_core/plugin_engine/plugins/builtin_plugins.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Provider extends PublicDomainPlugin {
  _Provider(this.providerId);
  final String providerId;
  @override
  PluginManifest get manifest =>
      PluginManifest.fromJson(super.manifest.toJson()..['id'] = providerId);
  @override
  Future<List<ContentItem>> search(String query, {int page = 1}) async => [
    ContentItem(
      id: 'tmdb_1_movie',
      title: 'Filme',
      posterUrl: '',
      type: ContentType.movie,
      pluginId: providerId,
    ),
    ContentItem(
      id: 'tmdb_2_movie',
      title: 'Homônimo',
      year: '1980',
      posterUrl: '',
      type: ContentType.movie,
      pluginId: providerId,
    ),
    ContentItem(
      id: 'tmdb_3_movie',
      title: 'Homônimo',
      year: '2020',
      posterUrl: '',
      type: ContentType.movie,
      pluginId: providerId,
    ),
  ];
}

void main() {
  test(
    'busca não repete o mesmo filme entre provedores e preserva homônimos',
    () async {
      final client = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {'results': []},
                ),
              );
            },
          ),
        );
      final manager = PluginManager(catalogClient: client);
      addTearDown(manager.dispose);
      manager.setInstalledPluginIds([]);
      manager.installPlugin(_Provider('provider.a'));
      manager.installPlugin(_Provider('provider.b'));
      final results = await manager.searchAll('Filme');
      expect(results.map((item) => item.id), [
        'tmdb_1_movie',
        'tmdb_2_movie',
        'tmdb_3_movie',
      ]);
      client.close();
    },
  );
}
