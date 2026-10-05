import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Utilitário HTTP para requisições e web scraping de plugins
class HttpBridge {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
      },
    ),
  );

  /// Executa GET retornando o corpo como String
  static Future<String> get(String url, {Map<String, String>? headers, Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dio.get(
        url,
        queryParameters: queryParams,
        options: Options(headers: headers),
      );
      return response.data.toString();
    } catch (e) {
      return '';
    }
  }

  /// Executa GET e retorna o DOM HTML parseado
  static Future<Document?> getHtml(String url, {Map<String, String>? headers}) async {
    final body = await get(url, headers: headers);
    if (body.isEmpty) return null;
    return html_parser.parse(body);
  }

  /// Executa POST
  static Future<String> post(String url, {dynamic data, Map<String, String>? headers}) async {
    try {
      final response = await _dio.post(
        url,
        data: data,
        options: Options(headers: headers),
      );
      return response.data.toString();
    } catch (e) {
      return '';
    }
  }
}
