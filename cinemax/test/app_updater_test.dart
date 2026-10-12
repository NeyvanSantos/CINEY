import 'dart:io';

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
        {
          'tag_name': 'tv-v1.0.999-malformed',
          'draft': false,
          'prerelease': true,
        },
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

  group('AppUpdateIntegrity', () {
    test('lê checksum sha256sum somente para o asset esperado', () {
      const assetName = 'CiNey-v1.0.33.apk';
      const hash =
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

      expect(
        AppUpdateIntegrity.parseSha256Checksum(
          '$hash  $assetName\n',
          assetName,
        ),
        hash,
      );
      expect(
        AppUpdateIntegrity.parseSha256Checksum(
          '$hash *$assetName\r\n',
          assetName,
        ),
        hash,
      );
      expect(
        AppUpdateIntegrity.parseSha256Checksum('$hash  other.apk\n', assetName),
        isNull,
      );
      expect(
        AppUpdateIntegrity.parseSha256Checksum(
          'invalid  $assetName\n',
          assetName,
        ),
        isNull,
      );
      expect(
        AppUpdateIntegrity.parseSha256Checksum(
          '$hash  $assetName\n$hash  $assetName\n',
          assetName,
        ),
        isNull,
      );
    });

    test('normaliza hashes e rejeita valores incompletos', () {
      const hash =
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

      expect(AppUpdateIntegrity.normalizeSha256('SHA256:$hash'), hash);
      expect(AppUpdateIntegrity.normalizeSha256('ba78:16bf'), isNull);
      expect(AppUpdateIntegrity.normalizeSha256(null), isNull);
    });

    test('valida o arquivo em streaming e falha sem hash confiável', () async {
      final directory = await Directory.systemTemp.createTemp(
        'ciney-updater-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}sample.apk');
      await file.writeAsString('abc');
      const hash =
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

      expect(await AppUpdateIntegrity.matchesFile(file, hash), isTrue);
      expect(
        await AppUpdateIntegrity.matchesFile(file, List.filled(64, '0').join()),
        isFalse,
      );
      expect(await AppUpdateIntegrity.matchesFile(file, null), isFalse);
    });
  });
}
