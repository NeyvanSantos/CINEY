import 'package:cinemax/core/services/app_updater.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUpdater', () {
    test('seleciona a release estável mais recente para mobile', () {
      final releases = [
        {'tag_name': 'v1.0.8', 'draft': false, 'prerelease': false},
        {'tag_name': 'v1.0.10', 'draft': false, 'prerelease': false},
        {'tag_name': 'v1.0.9', 'draft': false, 'prerelease': false},
        {'tag_name': 'tv-v1.0.11', 'draft': false, 'prerelease': true},
      ];

      final selected = AppUpdater.selectLatestRelease(releases, isTvApp: false);

      expect(selected, isNotNull);
      expect(selected!['tag_name'], 'v1.0.10');
    });

    test('ignora prereleases e releases em rascunho na mobile', () {
      final releases = [
        {'tag_name': 'v1.0.9', 'draft': false, 'prerelease': true},
        {'tag_name': 'v1.0.8', 'draft': true, 'prerelease': false},
        {'tag_name': 'v1.0.7', 'draft': false, 'prerelease': false},
      ];

      final selected = AppUpdater.selectLatestRelease(releases, isTvApp: false);

      expect(selected, isNotNull);
      expect(selected!['tag_name'], 'v1.0.7');
    });
  });
}
