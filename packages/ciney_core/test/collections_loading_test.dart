import 'dart:convert';
import 'dart:io' hide ContentType;
import 'dart:io' as io show ContentType;

import 'package:ciney_core/features/collections/presentation/movie_collection_screen.dart';
import 'package:ciney_core/plugin_engine/models/content_item.dart';
import 'package:ciney_core/plugin_engine/models/movie_collection.dart';
import 'package:ciney_core/plugin_engine/runtime/tmdb_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'conclui consultas, reutiliza a Home e permite repetir uma falha',
    (tester) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String, int>{};
      server.listen((request) async {
        final id = request.uri.pathSegments.last;
        final count = requests.update(
          id,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        request.response.headers.contentType = io.ContentType.json;
        if (id == '2102' && count == 1) {
          request.response.statusCode = HttpStatus.serviceUnavailable;
        } else {
          request.response.write(
            jsonEncode({
              'id': int.parse(id),
              'name': 'Coleção $id',
              'parts': [
                {
                  'id': 1,
                  'title': 'Primeiro filme',
                  'release_date': '2001-01-01',
                },
              ],
            }),
          );
        }
        await request.response.close();
      });
      final overrides = _CollectionHttpOverrides(server.port);
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          final collections = await TmdbService.getAvailableCollections(
            limit: 1,
          ).timeout(const Duration(seconds: 5));
          final opened = await TmdbService.getCollection(
            '9485',
            'com.megaflix',
          ).timeout(const Duration(seconds: 5));
          expect(identical(opened, collections.single), isTrue);
          expect(requests['9485'], 1);
          expect(opened.movies.single.title, 'Primeiro filme');

          final first = TmdbService.getCollection('2101', 'com.megaflix');
          final simultaneous = TmdbService.getCollection(
            '2101',
            'com.megaflix',
          );
          expect(identical(first, simultaneous), isTrue);
          await first.timeout(const Duration(seconds: 5));
          expect(requests['2101'], 1);

          await expectLater(
            TmdbService.getCollection(
              '2102',
              'com.megaflix',
            ).timeout(const Duration(seconds: 5)),
            throwsException,
          );
          final retried = await TmdbService.getCollection(
            '2102',
            'com.megaflix',
          ).timeout(const Duration(seconds: 5));
          expect(retried.movies, hasLength(1));
          expect(requests['2102'], 2);
        }, overrides);
      } finally {
        overrides.close();
        await server.close(force: true);
      }
    },
  );

  testWidgets('mostra erro e permite carregar os filmes ao tentar novamente', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MovieCollectionScreen(
          collectionId: '9485',
          pluginId: 'com.megaflix',
          collectionName: 'Coleção de teste',
          loadCollection: (_, _) async {
            if (++attempts == 1) throw StateError('Sem conexão');
            return MovieCollection(
              id: '9485',
              name: 'Coleção de teste',
              pluginId: 'com.megaflix',
              posterUrl: '',
              movies: [
                ContentItem(
                  id: 'tmdb_1_movie',
                  title: 'Filme recuperado',
                  posterUrl: '',
                  type: ContentType.movie,
                  pluginId: 'com.megaflix',
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar esta coleção.'),
      findsOneWidget,
    );
    expect(find.text('Nenhum filme disponível nesta coleção.'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Filme recuperado'), findsOneWidget);
    expect(find.text('Carregando filmes...'), findsNothing);
    expect(attempts, 2);
  });
}

// Exercita o cliente de produção, incluindo cache e requisições em andamento,
// com respostas HTTP locais, sem depender da disponibilidade do TMDB.
class _CollectionHttpOverrides extends HttpOverrides {
  final int port;
  final List<HttpClient> _clients = [];

  _CollectionHttpOverrides(this.port);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    _clients.add(client);
    return _CollectionHttpClient(client, port);
  }

  void close() {
    for (final client in _clients) {
      client.close(force: true);
    }
  }
}

class _CollectionHttpClient implements HttpClient {
  final HttpClient _client;
  final int port;

  _CollectionHttpClient(this._client, this.port);

  @override
  Duration? get connectionTimeout => _client.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _client.connectionTimeout = value;
  @override
  Duration get idleTimeout => _client.idleTimeout;
  @override
  set idleTimeout(Duration value) => _client.idleTimeout = value;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => _client.openUrl(
    method,
    url.host == 'api.themoviedb.org'
        ? url.replace(scheme: 'http', host: '127.0.0.1', port: port)
        : url,
  );

  @override
  void close({bool force = false}) => _client.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
