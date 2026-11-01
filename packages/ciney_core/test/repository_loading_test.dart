import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:ciney_core/plugin_engine/manager/plugin_manager.dart';
import 'package:ciney_core/plugin_engine/manager/repository_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('consulta URL informada e resolve manifesto relativo', () async {
    final urls = <String>[];
    final client = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            urls.add(request.uri.toString());
            final data = request.path.endsWith('repo.json')
                ? {
                    'plugins': [
                      {'manifest': 'plugin.json'},
                    ],
                  }
                : PluginManager.allAvailablePlugins.first.manifest.toJson();
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: ResponseBody.fromString(jsonEncode(data), 200),
              ),
            );
          },
        ),
      );
    final manager = RepositoryManager(client: client);
    addTearDown(manager.dispose);
    await manager.fetchRepositoryPlugins(
      'https://example.test/catalog/repo.json',
    );
    expect(urls, [
      'https://example.test/catalog/repo.json',
      'https://example.test/catalog/plugin.json',
    ]);
    expect(manager.state.availablePlugins, hasLength(1));
    expect(manager.state.error, isNull);
  });
  test('restaurar catálogo local invalida resposta remota pendente', () async {
    RequestInterceptorHandler? pending;
    RequestOptions? options;
    final arrived = Completer<void>();
    final client = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            pending = handler;
            options = request;
            arrived.complete();
          },
        ),
      );
    final manager = RepositoryManager(client: client);
    addTearDown(manager.dispose);
    final remote = manager.fetchRepositoryPlugins(
      'https://example.test/repo.json',
    );
    await arrived.future;
    await manager.fetchRepositoryPlugins(RepositoryState.bundled);
    pending!.resolve(
      Response(
        requestOptions: options!,
        statusCode: 200,
        data: ResponseBody.fromString('{"plugins":[]}', 200),
      ),
    );
    await remote;
    expect(manager.state.activeRepoUrl, RepositoryState.bundled);
    expect(manager.state.availablePlugins, isNotEmpty);
  });
  test('repositório inválido não anuncia sincronização bem sucedida', () async {
    final manager = RepositoryManager();
    addTearDown(manager.dispose);
    await manager.fetchRepositoryPlugins('http://invalid.test/repo.json');
    expect(manager.state.error, isNotNull);
  });
}
