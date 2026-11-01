import 'package:ciney_core/plugin_engine/runtime/tmdb_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('consulta com e prioriza o título exato com &', () async {
    final client = Dio()
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
                      'id': 111,
                      'media_type': 'movie',
                      'title': 'Velozes & Furiosos: Para Sempre',
                      'release_date': '2028-01-01',
                    },
                    {
                      'id': 222,
                      'media_type': 'movie',
                      'title': 'Velozes & Furiosos 10',
                      'release_date': '2023-01-01',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
    final results = await TmdbService.search(
      'Velozes e Furiosos 10',
      client: client,
    );
    expect(results.first.title, 'Velozes & Furiosos 10');
    client.close();
  });
}
