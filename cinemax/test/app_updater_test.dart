import 'package:cinemax/core/services/app_updater.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUpdater', () {
    test('TV seleciona maior versão numérica e mantém canais separados', () {
      final releases = [
        {'tag_name': 'tv-v1.0.9', 'draft': false, 'prerelease': true},
        {'tag_name': 'v1.0.99', 'draft': false, 'prerelease': false},
        {'tag_name': 'tv-v1.0.27', 'draft': true, 'prerelease': true},
        {'tag_name': 'tv-v1.0.28', 'draft': false, 'prerelease': false},
        {'tag_name': 'tv-v1.0.26', 'draft': false, 'prerelease': true},
        {'tag_name': 'tv-v1.0.25', 'draft': false, 'prerelease': true},
      ];
      final selected = AppUpdater.selectLatestRelease(releases, isTvApp: true);
      expect(selected!['tag_name'], 'tv-v1.0.26');
    });

    test('TV sem pré-lançamento publicado retorna nenhuma atualização', () {
      expect(
        AppUpdater.selectLatestRelease([
          {'tag_name': 'v1.0.99', 'draft': false, 'prerelease': false},
          {'tag_name': 'tv-v1.0.26', 'draft': true, 'prerelease': true},
        ], isTvApp: true),
        isNull,
      );
    });

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
