import '../models/stream_source.dart';

/// Resolve os endereços dos servidores a partir dos IDs do catálogo.
/// Os endereços devem ser incorporados em iframe.
class StreamResolverService {
  /// Gera as fontes de streaming priorizando servidores com áudio Dublado PT-BR.
  /// A ordem de prioridade é: Dublado > Multi-Áudio.
  /// A disponibilidade real depende de cada fornecedor.
  static List<StreamSource> resolveFromTmdbId({
    required String tmdbId,
    required bool isTv,
    int? season,
    int? episode,
  }) {
    final episodePath = season != null && episode != null
        ? '/$season/$episode'
        : '';

    // ── Prioridade 1: SuperFlix (Dublado PT-BR / Full HD) ──
    // Servidor brasileiro focado em conteúdo dublado em português.
    final superFlixUrl = isTv
        ? 'https://superflixapi.quest/serie/$tmdbId$episodePath'
        : 'https://superflixapi.quest/filme/$tmdbId';

    // ── Prioridade 2: EmbedMovies (Multi-Áudio / Fallback) ──
    // Servidor com múltiplas opções, geralmente inclui PT-BR quando disponível.
    final embedUrl = isTv
        ? 'https://myembed.biz/serie/$tmdbId$episodePath'
        : 'https://myembed.biz/filme/$tmdbId';

    return [
      // 🇧🇷 Servidores Dublados PT-BR (prioridade máxima)
      StreamSource(
        url: superFlixUrl,
        quality: '1080p Full HD',
        server: 'SuperFlix',
        isEmbed: true,
        isDirect: false,
        priority: 1,
        audioType: AudioType.dubbed,
      ),
      // 🌐 Servidor Multi-Áudio (fallback)
      StreamSource(
        url: embedUrl,
        quality: 'Conforme o fornecedor',
        server: 'EmbedMovies',
        isEmbed: true,
        isDirect: false,
        priority: 2,
        audioType: AudioType.mixed,
      ),
    ];
  }

  /// Extrai o TMDB ID numérico de um contentId no formato tmdb_123456_movie
  static String? extractTmdbId(String contentId) {
    if (!contentId.startsWith('tmdb_')) return null;
    final parts = contentId.split('_');
    if (parts.length < 3) return null;
    return parts[1];
  }

  /// Verifica se o conteúdo é TV (série, anime, dorama)
  static bool isTvContent(String contentId) {
    final parts = contentId.split('_');
    if (parts.length < 3) return false;
    final type = parts[2];
    return type == 'series' ||
        type == 'tv' ||
        type == 'anime' ||
        type == 'dorama';
  }

  static final Map<String, (String tmdbId, bool isTv)> _internalIdMap = {
    // MegaFlix (Filmes)
    'mf_1': ('693134', false), // Duna: Parte 2
    'mf_2': ('533535', false), // Deadpool & Wolverine
    'mf_3': ('558449', false), // Gladiador II
    'mf_4': ('872585', false), // Oppenheimer
    'mf_5': ('157336', false), // Interestelar
    'mf_6': ('299534', false), // Vingadores: Ultimato
    'mf_7': ('414906', false), // Batman
    'mf_8': ('603692', false), // John Wick 4
    'mf_9': ('361743', false), // Top Gun: Maverick
    'mf_10': ('27205', false), // A Origem
    // SuperCine (Séries)
    'sc_1': ('94997', true), // House of the Dragon
    'sc_2': ('66732', true), // Stranger Things
    'sc_3': ('76479', true), // The Boys
    'sc_4': ('100088', true), // The Last of Us
    'sc_5': ('1396', true), // Breaking Bad
    'sc_6': ('1399', true), // Game of Thrones
    'sc_7': ('119051', true), // Wandinha
    'sc_8': ('84958', true), // Loki
    // AnimesCloud (Animes)
    'ac_1': ('85937', true), // Demon Slayer
    'ac_2': ('1429', true), // Attack on Titan
    'ac_3': ('95479', true), // Jujutsu Kaisen
    'ac_4': ('209867', true), // Solo Leveling
    'ac_5': ('37854', true), // One Piece
    'ac_6': ('31910', true), // Naruto Shippuden
    'ac_7': ('114410', true), // Chainsaw Man
    // Doramas
    'dr_1': ('241257', true), // Rainha das Lágrimas
    'dr_2': ('96462', true), // Pousando no Amor
    'dr_3': ('135157', true), // Alquimia das Almas
    'dr_4': ('99966', true), // All of Us Are Dead
  };

  /// Resolve streams para um contentId genérico (tmdb_ ou interno)
  static List<StreamSource> resolveFromContentId(
    String contentId, {
    int? season,
    int? episode,
  }) {
    final tmdbId = extractTmdbId(contentId);
    if (tmdbId != null) {
      return resolveFromTmdbId(
        tmdbId: tmdbId,
        isTv: isTvContent(contentId),
        season: season,
        episode: episode,
      );
    }

    // Busca no mapa de itens pré-cadastrados
    if (_internalIdMap.containsKey(contentId)) {
      final item = _internalIdMap[contentId]!;
      return resolveFromTmdbId(
        tmdbId: item.$1,
        isTv: item.$2,
        season: season,
        episode: episode,
      );
    }

    return [];
  }
}
