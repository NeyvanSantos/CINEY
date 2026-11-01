import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ciney_core/plugin_engine/manager/plugin_manager.dart';
import 'package:ciney_core/plugin_engine/plugins/builtin_plugins.dart';
import 'package:ciney_core/plugin_engine/models/content_item.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingPlugin extends PublicDomainPlugin {
  final pending = Completer<ContentDetail>();
  @override
  Future<ContentDetail> getDetail(String id) => pending.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('extensões e seleção vazia persistem entre inicializações', () async {
    SharedPreferences.setMockInitialValues({});
    final first = PluginManager(
      preferencesLoader: SharedPreferences.getInstance,
    );
    await first.ready;
    first.setInstalledPluginIds(['com.supercine']);
    await first.flushConfiguration();
    first.dispose();
    final second = PluginManager(
      preferencesLoader: SharedPreferences.getInstance,
    );
    await second.ready;
    expect(second.state.installedPlugins.map((p) => p.manifest.id), [
      'com.supercine',
    ]);
    second.setInstalledPluginIds([]);
    await second.flushConfiguration();
    second.dispose();
    final third = PluginManager(
      preferencesLoader: SharedPreferences.getInstance,
    );
    await third.ready;
    expect(third.state.installedPlugins, isEmpty);
    expect(third.state.activePlugin, isNull);
    third.dispose();
  });
  test('ID local usa temporadas e episódios reais do ID canônico', () async {
    final paths = <String>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            paths.add(request.path);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: request.path.endsWith('/season/3')
                    ? {
                        'episodes': [
                          {'episode_number': 9, 'name': 'Final real'},
                        ],
                      }
                    : {
                        'id': 94997,
                        'name': 'Título correto',
                        'number_of_seasons': 3,
                        'seasons': [
                          {'season_number': 3, 'episode_count': 9},
                        ],
                      },
              ),
            );
          },
        ),
      );
    final manager = PluginManager(catalogClient: dio);
    addTearDown(manager.dispose);
    final detail = await manager.getDetail('sc_1', 'com.supercine');
    expect(detail!.id, 'sc_1');
    expect(detail.seasons!.single.number, 3);
    final episodes = await manager.getEpisodes('sc_1', 'com.supercine', 3);
    expect(episodes.single.episodeNumber, 9);
    expect(paths, ['/tv/94997', '/tv/94997/season/3']);
  });
  test('seleção vazia mantém nenhuma extensão instalada', () {
    final manager = PluginManager();
    addTearDown(manager.dispose);
    manager.setInstalledPluginIds([]);
    expect(manager.state.installedPlugins, isEmpty);
    expect(manager.state.activePlugin, isNull);
  });
  test('catálogo sem ID fixo recusa resultado de outro filme', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'results': [
                    {
                      'id': 987654,
                      'title': 'Outro filme',
                      'release_date': '2024-01-01',
                      'media_type': 'movie',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
    final manager = PluginManager(catalogClient: dio);
    addTearDown(manager.dispose);
    final detail = await manager.getDetail('am_1', 'com.amenictv');
    expect(detail!.id, 'am_1');
    expect(detail.title, 'Moana 2');
    expect(detail.cast, isEmpty);
    expect(detail.duration, isNull);
    expect(await manager.getStreams('am_1', 'com.amenictv'), isEmpty);
  });
  test(
    'catálogo sem ID fixo aceita correspondência única de título tipo e ano',
    () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              final searching = request.path == '/search/multi';
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: searching
                      ? {
                          'results': [
                            {
                              'id': 123456,
                              'title': 'Moana 2',
                              'release_date': '2024-01-01',
                              'media_type': 'movie',
                            },
                          ],
                        }
                      : {
                          'id': 123456,
                          'title': 'Moana 2',
                          'release_date': '2024-01-01',
                        },
                ),
              );
            },
          ),
        );
      final manager = PluginManager(catalogClient: dio);
      addTearDown(manager.dispose);
      expect((await manager.getDetail('am_1', 'com.amenictv'))!.id, 'am_1');
      expect(
        (await manager.getStreams('am_1', 'com.amenictv')).first.url,
        contains('123456'),
      );
    },
  );
  test('resposta de extensão removida não repopula cache', () async {
    final manager = PluginManager();
    addTearDown(manager.dispose);
    for (final plugin in [...manager.state.installedPlugins]) {
      manager.removePlugin(plugin.manifest.id);
    }
    final plugin = _PendingPlugin();
    manager.installPlugin(plugin);
    final request = manager.getDetail('review_unknown', plugin.manifest.id);
    await Future<void>.delayed(Duration.zero);
    manager.removePlugin(plugin.manifest.id);
    plugin.pending.complete(
      ContentDetail(
        id: 'review_unknown',
        title: 'Antigo',
        posterUrl: '',
        type: ContentType.movie,
        pluginId: plugin.manifest.id,
      ),
    );
    await request;
    expect(
      await manager.getDetail('review_unknown', plugin.manifest.id),
      isNull,
    );
  });
  test('falha TMDB não substitui título nem fabrica episódios', () async {
    await HttpOverrides.runZoned(() async {
      final manager = PluginManager();
      addTearDown(manager.dispose);
      expect(
        await manager.getDetail('tmdb_987654_series', 'com.supercine'),
        isNull,
      );
      expect(await manager.getEpisodes('sc_1', 'com.supercine', 999), isEmpty);
    }, createHttpClient: (_) => throw const SocketException('offline'));
  });
}
