import '../models/content_item.dart';
import '../models/plugin_manifest.dart';
import '../models/stream_source.dart';

/// Contrato padronizado que todo Plugin deve implementar.
/// Seja em Dart nativo ou via runtime JavaScript / Scraping.
abstract class PluginInterface {
  /// Manifesto com metadados do plugin
  PluginManifest get manifest;

  /// Retorna as seções da página inicial (Em Alta, Lançamentos, etc.)
  Future<List<ContentCategory>> getHome();

  /// Realiza busca por termo (filmes, séries, animes)
  Future<List<ContentItem>> search(String query, {int page = 1});

  /// Retorna informações detalhadas do título selecionado
  Future<ContentDetail> getDetail(String contentId);

  /// Retorna as fontes de reprodução/streaming de vídeo disponíveis
  Future<List<StreamSource>> getStreams(String contentId, {int? season, int? episode});

  /// Retorna episódios de uma série/temporada específica
  Future<List<ContentItem>> getEpisodes(String seriesId, int season);
}
