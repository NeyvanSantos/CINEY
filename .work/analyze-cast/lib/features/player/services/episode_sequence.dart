import '../../../plugin_engine/models/content_item.dart';

class EpisodeTarget {
  const EpisodeTarget(this.season, this.number, this.title);

  final int season;
  final int number;
  final String title;
}

/// Uses the catalog's episode numbers, including gaps and season boundaries.
class EpisodeSequence {
  EpisodeSequence({
    required this.loadDetail,
    required this.loadEpisodes,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Future<ContentDetail?> Function() loadDetail;
  final Future<List<ContentItem>> Function(int season) loadEpisodes;
  final DateTime Function() _now;

  Future<EpisodeTarget?> next(int season, int episode) async {
    final episodes = await _availableEpisodes(season);
    for (final candidate in episodes) {
      if (candidate.number > episode) return candidate;
    }
    // An empty response may be a network failure. Never guess the boundary.
    if (!episodes.any((candidate) => candidate.number == episode)) {
      throw StateError('Não foi possível confirmar a lista de episódios.');
    }
    final detail = await loadDetail();
    if (detail == null) {
      throw StateError('Não foi possível confirmar as temporadas.');
    }
    if (detail.seasons?.isNotEmpty != true && detail.totalSeasons == null) {
      throw StateError('O catálogo não informou as temporadas desta série.');
    }
    final seasons =
        detail.seasons?.map((item) => item.number).toSet() ??
        {for (var n = 1; n <= (detail.totalSeasons ?? 0); n++) n};
    final following = seasons.where((number) => number > season).toList()
      ..sort();
    for (final number in following) {
      if (detail.seasons?.any(
            (item) => item.number == number && item.episodeCount == 0,
          ) ==
          true) {
        continue;
      }
      final candidates = await _availableEpisodes(number);
      if (candidates.isNotEmpty) return candidates.first;
      // Do not skip a season whose episodes have not aired yet.
      return null;
    }
    return null;
  }

  Future<List<EpisodeTarget>> _availableEpisodes(int season) async {
    final items = await loadEpisodes(season);
    if (items.isEmpty) {
      throw StateError(
        'Não foi possível carregar os episódios da temporada $season.',
      );
    }
    final today = _now();
    final date = DateTime(today.year, today.month, today.day);
    final result = <EpisodeTarget>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      // TMDB stores the episode's air date in year. Other catalogs may omit it.
      final airDate = DateTime.tryParse(item.year ?? '');
      if (airDate != null && airDate.isAfter(date)) continue;
      final number = item.episodeNumber ?? index + 1;
      if (number > 0) result.add(EpisodeTarget(season, number, item.title));
    }
    return result..sort((a, b) => a.number.compareTo(b.number));
  }
}
