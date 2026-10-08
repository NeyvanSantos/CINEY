import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final playbackPreferencesRepositoryProvider =
    Provider<PlaybackPreferencesRepository>(
      (ref) => PlaybackPreferencesRepository(),
    );

final playbackPreferencesProvider =
    AsyncNotifierProvider<PlaybackPreferencesController, PlaybackPreferences>(
      PlaybackPreferencesController.new,
    );

class PlaybackPreferences {
  const PlaybackPreferences({
    this.resumePlayback = true,
    this.autoHideControls = true,
    this.landscapeOnMobile = true,
    this.autoPlayNextEpisode = true,
  });

  static const defaults = PlaybackPreferences();

  final bool resumePlayback;
  final bool autoHideControls;
  final bool landscapeOnMobile;
  final bool autoPlayNextEpisode;

  PlaybackPreferences copyWith({
    bool? resumePlayback,
    bool? autoHideControls,
    bool? landscapeOnMobile,
    bool? autoPlayNextEpisode,
  }) {
    return PlaybackPreferences(
      resumePlayback: resumePlayback ?? this.resumePlayback,
      autoHideControls: autoHideControls ?? this.autoHideControls,
      landscapeOnMobile: landscapeOnMobile ?? this.landscapeOnMobile,
      autoPlayNextEpisode: autoPlayNextEpisode ?? this.autoPlayNextEpisode,
    );
  }
}

class PlaybackPreferencesRepository {
  PlaybackPreferencesRepository({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const _resumePlaybackKey = 'playback-resume-enabled';
  static const _autoHideControlsKey = 'playback-auto-hide-controls';
  static const _landscapeOnMobileKey = 'playback-landscape-on-mobile';
  static const _autoPlayNextEpisodeKey = 'playback-auto-next-episode';

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<PlaybackPreferences> load() async {
    final preferences = await _preferencesLoader();
    return PlaybackPreferences(
      resumePlayback: preferences.getBool(_resumePlaybackKey) ?? true,
      autoHideControls: preferences.getBool(_autoHideControlsKey) ?? true,
      landscapeOnMobile: preferences.getBool(_landscapeOnMobileKey) ?? true,
      autoPlayNextEpisode: preferences.getBool(_autoPlayNextEpisodeKey) ?? true,
    );
  }

  Future<void> save(PlaybackPreferences value) async {
    final preferences = await _preferencesLoader();
    await preferences.setBool(_resumePlaybackKey, value.resumePlayback);
    await preferences.setBool(_autoHideControlsKey, value.autoHideControls);
    await preferences.setBool(_landscapeOnMobileKey, value.landscapeOnMobile);
    await preferences.setBool(
      _autoPlayNextEpisodeKey,
      value.autoPlayNextEpisode,
    );
  }
}

class PlaybackPreferencesController extends AsyncNotifier<PlaybackPreferences> {
  @override
  Future<PlaybackPreferences> build() =>
      ref.read(playbackPreferencesRepositoryProvider).load();

  Future<void> setPreferences(PlaybackPreferences value) async {
    final previous = state.valueOrNull ?? PlaybackPreferences.defaults;
    state = AsyncData(value);
    try {
      await ref.read(playbackPreferencesRepositoryProvider).save(value);
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
