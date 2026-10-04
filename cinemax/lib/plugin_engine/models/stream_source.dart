/// Fonte de stream de vídeo
/// Retornado pela função getStreams() do plugin
class StreamSource {
  final String url;
  final String quality;
  final String server;
  final Map<String, String>? headers;
  final List<Subtitle>? subtitles;
  final bool isM3U8;
  final bool isDirect;
  final bool isEmbed; // Se true, carrega em WebView ao invés do player nativo
  /// Prioridade do servidor (menor = melhor). Usado para ordenar do melhor ao pior.
  /// O player tenta o de menor priority primeiro e faz fallback automático.
  final int priority;

  const StreamSource({
    required this.url,
    required this.quality,
    required this.server,
    this.headers,
    this.subtitles,
    this.isM3U8 = false,
    this.isDirect = true,
    this.isEmbed = false,
    this.priority = 100,
  });

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    return StreamSource(
      url: json['url']?.toString() ?? '',
      quality: json['quality']?.toString() ?? 'Auto',
      server: json['server']?.toString() ?? 'Default',
      headers: (json['headers'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v.toString())),
      subtitles: (json['subtitles'] as List<dynamic>?)
          ?.map((e) => Subtitle.fromJson(e as Map<String, dynamic>))
          .toList(),
      isM3U8: json['isM3U8'] == true ||
          (json['url']?.toString().contains('.m3u8') ?? false),
      isDirect: json['isDirect'] != false,
      isEmbed: json['isEmbed'] == true,
      priority: (json['priority'] as int?) ?? 100,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'quality': quality,
      'server': server,
      'headers': headers,
      'subtitles': subtitles?.map((e) => e.toJson()).toList(),
      'isM3U8': isM3U8,
      'isDirect': isDirect,
      'isEmbed': isEmbed,
      'priority': priority,
    };
  }
}

/// Legenda
class Subtitle {
  final String url;
  final String language;
  final String? label;
  final SubtitleFormat format;

  const Subtitle({
    required this.url,
    required this.language,
    this.label,
    this.format = SubtitleFormat.srt,
  });

  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(
      url: json['url']?.toString() ?? '',
      language: json['language']?.toString() ?? json['lang']?.toString() ?? 'pt-BR',
      label: json['label']?.toString(),
      format: SubtitleFormat.fromString(
          json['format']?.toString() ?? 'srt'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'language': language,
      'label': label,
      'format': format.value,
    };
  }
}

/// Formato de legenda
enum SubtitleFormat {
  srt('srt'),
  vtt('vtt'),
  ass('ass');

  final String value;
  const SubtitleFormat(this.value);

  static SubtitleFormat fromString(String value) {
    return SubtitleFormat.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => SubtitleFormat.srt,
    );
  }
}
