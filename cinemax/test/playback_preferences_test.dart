import 'package:cinemax/features/profile/services/playback_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('usa preferências funcionais padrão', () async {
    final preferences = await PlaybackPreferencesRepository().load();

    expect(preferences.resumePlayback, isTrue);
    expect(preferences.autoHideControls, isTrue);
    expect(preferences.landscapeOnMobile, isTrue);
    expect(preferences.autoPlayNextEpisode, isTrue);
  });

  test('persiste preferências de reprodução', () async {
    const expected = PlaybackPreferences(
      resumePlayback: false,
      autoHideControls: false,
      landscapeOnMobile: false,
      autoPlayNextEpisode: false,
    );
    final repository = PlaybackPreferencesRepository();

    await repository.save(expected);

    final actual = await repository.load();
    expect(actual.resumePlayback, expected.resumePlayback);
    expect(actual.autoHideControls, expected.autoHideControls);
    expect(actual.landscapeOnMobile, expected.landscapeOnMobile);
    expect(actual.autoPlayNextEpisode, isFalse);
  });

  test(
    'migrar preferências antigas ativa continuidade sem perder ajustes',
    () async {
      SharedPreferences.setMockInitialValues({
        'playback-resume-enabled': false,
      });
      final value = await PlaybackPreferencesRepository().load();
      expect(value.resumePlayback, isFalse);
      expect(value.autoPlayNextEpisode, isTrue);
      expect(
        value.copyWith(autoPlayNextEpisode: false).resumePlayback,
        isFalse,
      );
    },
  );
}
