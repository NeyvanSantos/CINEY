import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:cinemax/plugin_engine/runtime/tmdb_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemax/plugin_engine/models/movie_collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cinemax/features/collections/presentation/movie_collection_screen.dart';

void main() {
  test('mapeia a coleção associada ao detalhe de um filme TMDB', () async {
    final client = Dio(BaseOptions(baseUrl: 'https://tmdb.test/3'));
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/movie/9799');
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'id': 9799,
                'title': 'Velozes e Furiosos',
                'release_date': '2001-06-22',
                'belongs_to_collection': {
                  'id': 9485,
                  'name': 'Velozes e Furiosos: Coleção',
                },
              },
            ),
          );
        },
      ),
    );

    final detail = await TmdbService.getDetail(
      'tmdb_9799_movie',
      'com.megaflix',
      client: client,
    );

    expect(detail?.collectionId, '9485');
    expect(detail?.collectionName, 'Velozes e Furiosos: Coleção');
    expect(detail?.type, ContentType.movie);
  });

  test(
    'mantém a coleção ausente quando o filme não tem associação TMDB',
    () async {
      final client = Dio(BaseOptions(baseUrl: 'https://tmdb.test/3'));
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 1,
                  'title': 'Filme independente',
                  'release_date': '2024-01-01',
                  'belongs_to_collection': null,
                },
              ),
            );
          },
        ),
      );

      final detail = await TmdbService.getDetail(
        'tmdb_1_movie',
        'com.megaflix',
        client: client,
      );

      expect(detail?.collectionId, isNull);
      expect(detail?.collectionName, isNull);
    },
  );

  test(
    'ordena filmes por lançamento e deixa datas ausentes no final',
    () async {
      final client = Dio(BaseOptions(baseUrl: 'https://tmdb.test/3'));
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/collection/9485');
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 9485,
                  'name': 'Velozes e Furiosos: Coleção',
                  'poster_path': '/collection.jpg',
                  'parts': [
                    {
                      'id': 2,
                      'title': 'Segundo filme',
                      'release_date': '2003-06-06',
                      'poster_path': '/second.jpg',
                    },
                    {
                      'id': 3,
                      'title': 'Primeiro filme',
                      'release_date': '2001-06-22',
                      'poster_path': '/first.jpg',
                    },
                    {
                      'id': 4,
                      'title': 'Data desconhecida',
                      'poster_path': '/unknown.jpg',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final collection = await TmdbService.getCollection(
        '9485',
        'com.megaflix',
        client: client,
      );

      expect(collection.name, 'Velozes e Furiosos: Coleção');
      expect(collection.posterUrl, endsWith('/collection.jpg'));
      expect(collection.movies.map((item) => item.title), [
        'Primeiro filme',
        'Segundo filme',
        'Data desconhecida',
      ]);
      expect(
        collection.movies.every((item) => item.type == ContentType.movie),
        isTrue,
      );
    },
  );

  test(
    'propaga falha ao consultar uma coleção para permitir nova tentativa',
    () {
      final client = Dio(BaseOptions(baseUrl: 'https://tmdb.test/3'));
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );

      expect(
        TmdbService.getCollection('9485', 'com.megaflix', client: client),
        throwsA(isA<DioException>()),
      );
    },
  );

  testWidgets('abre a ficha do filme selecionado na coleção', (tester) async {
    final movie = ContentItem(
      id: 'tmdb_1_movie',
      title: 'Filme da franquia',
      posterUrl: '',
      year: '2024',
      type: ContentType.movie,
      pluginId: 'com.megaflix',
    );
    final collection = MovieCollection(
      id: '9485',
      name: 'Coleção de teste',
      pluginId: 'com.megaflix',
      posterUrl: '',
      movies: [movie],
    );
    final router = GoRouter(
      initialLocation:
          '/collection/9485/com.megaflix?name=Coleção%20de%20teste',
      routes: [
        GoRoute(
          path: '/collection/:collectionId/:pluginId',
          builder: (context, state) => MovieCollectionScreen(
            collectionId: state.pathParameters['collectionId']!,
            pluginId: state.pathParameters['pluginId']!,
            collectionName: state.uri.queryParameters['name']!,
            loadCollection: (_, _) async => collection,
          ),
        ),
        GoRoute(
          path: '/details/:contentId/:pluginId',
          builder: (context, state) => Scaffold(
            body: Text('Detalhes: ${state.pathParameters['contentId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Filme da franquia'), findsOneWidget);

    await tester.tap(find.text('Filme da franquia'));
    await tester.pumpAndSettle();

    expect(find.text('Detalhes: tmdb_1_movie'), findsOneWidget);
  });
}
