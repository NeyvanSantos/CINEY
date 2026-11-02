import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_environment.dart';
import 'app_logger.dart';

// ═══════════════════════════════════════════════════════════════
// CONFIGURE AQUI: Seu repositório GitHub público
// ═══════════════════════════════════════════════════════════════
const String kGitHubOwner = 'NeyvanSantos';
const String kGitHubRepo = 'CINEY';
const String kTvReleaseTagPrefix = 'tv-v';
// ═══════════════════════════════════════════════════════════════

class AppUpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String releaseName;
  final int fileSize;
  final bool hasUpdate;
  final String htmlUrl;
  final String? sha256Hash;
  final bool isOfficialRelease;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.releaseName,
    required this.fileSize,
    required this.hasUpdate,
    required this.htmlUrl,
    this.sha256Hash,
    this.isOfficialRelease = true,
  });
}

enum InstallPermissionStatus { granted, denied, permanentlyDenied }

class AppUpdateIntegrity {
  static String? normalizeSha256(String? value) {
    if (value == null) return null;
    var hash = value.trim();
    if (hash.toLowerCase().startsWith('sha256:')) {
      hash = hash.substring('sha256:'.length);
    }
    hash = hash.replaceAll(':', '').toLowerCase();
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ? hash : null;
  }

  static String? parseSha256Checksum(String content, String assetName) {
    final lines = content.trimRight().split(RegExp(r'\r?\n'));
    if (lines.length != 1) return null;
    final match = RegExp(
      r'^([0-9a-fA-F]{64}) [ *](.+)$',
    ).firstMatch(lines.single);
    if (match == null || match.group(2) != assetName) return null;
    return match.group(1)!.toLowerCase();
  }

  static Future<bool> matchesFile(File file, String? expectedSha256) async {
    final expected = normalizeSha256(expectedSha256);
    if (expected == null) return false;
    final actual = await sha256.bind(file.openRead()).first;
    return actual.toString() == expected;
  }
}

class AppUpdater {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'CiNey-Updater',
      },
    ),
  );

  /// Selects the newest published release in the requested update channel.
  static Map<String, dynamic>? selectLatestRelease(
    List<dynamic> releases, {
    required bool isTvApp,
  }) {
    final prefix = isTvApp ? kTvReleaseTagPrefix : 'v';
    final tagPattern = RegExp(
      isTvApp ? r'^tv-v\d+\.\d+\.\d+$' : r'^v\d+\.\d+\.\d+$',
    );
    final matchingReleases = releases.whereType<Map<String, dynamic>>().where((
      release,
    ) {
      final tag = release['tag_name'];
      return tag is String &&
          tagPattern.hasMatch(tag) &&
          release['draft'] != true &&
          (isTvApp || release['prerelease'] != true);
    }).toList();
    // TV used prereleases historically. Prefer the official channel once it
    // exists, while allowing older installations to discover legacy releases.
    if (isTvApp &&
        matchingReleases.any((release) => release['prerelease'] != true)) {
      matchingReleases.removeWhere((release) => release['prerelease'] == true);
    }
    matchingReleases.sort((first, second) {
      final firstVersion = (first['tag_name'] as String).substring(
        prefix.length,
      );
      final secondVersion = (second['tag_name'] as String).substring(
        prefix.length,
      );
      return _compareVersions(secondVersion, firstVersion);
    });
    return matchingReleases.isEmpty ? null : matchingReleases.first;
  }

  /// Verifica se existe uma atualização no GitHub Releases
  static Future<AppUpdateInfo?> checkForUpdates() async {
    try {
      AppLogger.info('Verificando atualizações no GitHub...', tag: 'UPDATER');

      final packageInfo = await PackageInfo.fromPlatform();
      if (AppEnvironment.isTv &&
          packageInfo.packageName == 'com.ciney.tv.local') {
        AppLogger.info(
          'Versão local de teste usa instalação manual.',
          tag: 'UPDATER',
        );
        return null;
      }
      final currentVersion = packageInfo.version;
      final isTvApp = AppEnvironment.isTv;

      final response = await _dio.get(
        'https://api.github.com/repos/$kGitHubOwner/$kGitHubRepo/releases'
        '${isTvApp ? '?per_page=100' : '/latest'}',
      );

      if (response.statusCode != 200) {
        AppLogger.warn(
          'GitHub API retornou status ${response.statusCode}',
          tag: 'UPDATER',
        );
        return null;
      }

      final Map<String, dynamic> data;
      if (isTvApp) {
        final releases = response.data as List<dynamic>? ?? const <dynamic>[];
        final latest = selectLatestRelease(releases, isTvApp: true);
        if (latest == null) return null;
        data = latest;
      } else {
        data = response.data as Map<String, dynamic>;
      }
      final tagName = (data['tag_name'] as String?) ?? '';
      final tagMatch =
          (isTvApp
                  ? RegExp(r'^tv-v(\d+\.\d+\.\d+)$')
                  : RegExp(r'^v(\d+\.\d+\.\d+)$'))
              .firstMatch(tagName);
      if (tagMatch == null || data['draft'] == true) return null;
      if (!isTvApp && data['prerelease'] == true) {
        return null;
      }
      final latestVersion = tagMatch.group(1)!;
      final releaseName = (data['name'] as String?) ?? 'Nova Atualização';
      final releaseNotes = (data['body'] as String?) ?? 'Sem notas de versão.';
      final htmlUrl = (data['html_url'] as String?) ?? '';
      final assets = (data['assets'] as List<dynamic>?) ?? [];
      final author = data['author'] as Map<String, dynamic>?;

      // Verifica se a release é do autor oficial
      final isOfficial = author?['login'] == kGitHubOwner;

      final assetName = isTvApp
          ? 'CiNey-v$latestVersion-TV.apk'
          : 'CiNey-v$latestVersion.apk';
      Map<String, dynamic>? apkAsset;
      Map<String, dynamic>? checksumAsset;
      for (final asset in assets.whereType<Map<String, dynamic>>()) {
        if (asset['name'] == assetName) apkAsset = asset;
        if (asset['name'] == '$assetName.sha256') checksumAsset = asset;
      }
      if (apkAsset == null) {
        AppLogger.warn(
          'Release $tagName não contém $assetName.',
          tag: 'UPDATER',
        );
        return null;
      }

      final downloadUrl = apkAsset['browser_download_url']?.toString() ?? '';
      final fileSize = apkAsset['size'] as int? ?? 0;
      if (fileSize <= 0 ||
          !_isReleaseAssetUrl(downloadUrl, tagName, assetName)) {
        AppLogger.error(
          'Asset de atualização inválido na release $tagName.',
          tag: 'UPDATER',
        );
        return null;
      }

      var sha256Hash = AppUpdateIntegrity.normalizeSha256(
        apkAsset['digest']?.toString(),
      );
      sha256Hash ??= AppUpdateIntegrity.normalizeSha256(
        apkAsset['label']?.toString(),
      );
      if (sha256Hash == null && checksumAsset != null) {
        final checksumUrl =
            checksumAsset['browser_download_url']?.toString() ?? '';
        if (_isReleaseAssetUrl(checksumUrl, tagName, '$assetName.sha256')) {
          final checksumResponse = await _dio.get<String>(
            checksumUrl,
            options: Options(responseType: ResponseType.plain),
          );
          sha256Hash = AppUpdateIntegrity.parseSha256Checksum(
            checksumResponse.data ?? '',
            assetName,
          );
        }
      }
      if (sha256Hash == null) {
        AppLogger.error(
          'Release $tagName não fornece SHA-256 válido para $assetName.',
          tag: 'SECURITY',
        );
        return null;
      }

      final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;

      AppLogger.info(
        'Versão atual: $currentVersion | Última: $latestVersion | '
        'Atualização: ${hasUpdate ? "SIM" : "NÃO"} | '
        'Oficial: ${isOfficial ? "SIM ✅" : "NÃO ⚠️"}',
        tag: 'UPDATER',
      );

      return AppUpdateInfo(
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
        releaseName: releaseName,
        fileSize: fileSize,
        hasUpdate: hasUpdate,
        htmlUrl: htmlUrl,
        sha256Hash: sha256Hash,
        isOfficialRelease: isOfficial,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        AppLogger.warn(
          'Nenhuma release encontrada no repositório $kGitHubOwner/$kGitHubRepo',
          tag: 'UPDATER',
        );
      } else {
        AppLogger.error(
          'Erro de rede ao verificar atualizações: ${e.message}',
          tag: 'UPDATER',
        );
      }
      return null;
    } catch (e) {
      AppLogger.error(
        'Erro inesperado ao verificar atualizações: $e',
        tag: 'UPDATER',
      );
      return null;
    }
  }

  /// Solicita permissão para instalar apps de fontes externas
  static Future<InstallPermissionStatus> requestInstallPermission() async {
    if (!Platform.isAndroid) return InstallPermissionStatus.granted;

    try {
      final status = await Permission.requestInstallPackages.status;

      if (status.isGranted) {
        AppLogger.info(
          'Permissão de instalação já concedida ✅',
          tag: 'UPDATER',
        );
        return InstallPermissionStatus.granted;
      }

      // Solicita a permissão
      AppLogger.info('Solicitando permissão de instalação...', tag: 'UPDATER');
      final result = await Permission.requestInstallPackages.request();

      if (result.isGranted) {
        AppLogger.info('Permissão de instalação concedida ✅', tag: 'UPDATER');
        return InstallPermissionStatus.granted;
      } else if (result.isPermanentlyDenied) {
        AppLogger.warn('Permissão negada permanentemente', tag: 'UPDATER');
        return InstallPermissionStatus.permanentlyDenied;
      } else {
        AppLogger.warn('Permissão negada pelo usuário', tag: 'UPDATER');
        return InstallPermissionStatus.denied;
      }
    } catch (e) {
      AppLogger.error('Erro ao solicitar permissão: $e', tag: 'UPDATER');
      return InstallPermissionStatus.denied;
    }
  }

  /// Baixa o APK com callback de progresso (0.0 a 1.0) e verifica integridade
  static Future<File?> downloadApk(
    String downloadUrl, {
    required ValueChanged<double> onProgress,
    String? expectedSha256,
    int? expectedSizeBytes,
  }) async {
    final expectedHash = AppUpdateIntegrity.normalizeSha256(expectedSha256);
    if (expectedHash == null || !_isGithubReleaseAssetUrl(downloadUrl)) {
      AppLogger.error(
        'Download recusado: URL ou SHA-256 da atualização inválido.',
        tag: 'SECURITY',
      );
      return null;
    }

    File? file;
    try {
      AppLogger.info('Iniciando download do APK...', tag: 'UPDATER');

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}${Platform.pathSeparator}cinemax_update_${DateTime.now().microsecondsSinceEpoch}.apk';
      file = File(filePath);

      await _dio.download(
        downloadUrl,
        filePath,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );

      if (await file.exists()) {
        final sizeInMb = (await file.length()) / (1024 * 1024);
        AppLogger.info(
          'Download completo! Tamanho: ${sizeInMb.toStringAsFixed(1)} MB',
          tag: 'UPDATER',
        );

        if (expectedSizeBytes != null &&
            await file.length() != expectedSizeBytes) {
          AppLogger.error(
            'Tamanho do APK diverge do asset publicado.',
            tag: 'SECURITY',
          );
          await file.delete();
          return null;
        }

        AppLogger.info('Verificando integridade SHA-256...', tag: 'UPDATER');
        if (!await AppUpdateIntegrity.matchesFile(file, expectedHash)) {
          AppLogger.error(
            'SHA-256 do APK baixado não confere.',
            tag: 'SECURITY',
          );
          await file.delete();
          return null;
        }
        AppLogger.info('Integridade verificada com sucesso ✅', tag: 'SECURITY');

        return file;
      }

      return null;
    } catch (e) {
      AppLogger.error('Erro ao baixar APK: $e', tag: 'UPDATER');
      if (file != null && await file.exists()) {
        try {
          await file.delete();
        } catch (cleanupError) {
          AppLogger.warn(
            'Falha ao limpar download incompleto: $cleanupError',
            tag: 'UPDATER',
          );
        }
      }
      return null;
    }
  }

  static bool _isReleaseAssetUrl(String value, String tag, String assetName) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }
    final segments = uri.pathSegments;
    return segments.length == 6 &&
        segments[0] == kGitHubOwner &&
        segments[1] == kGitHubRepo &&
        segments[2] == 'releases' &&
        segments[3] == 'download' &&
        segments[4] == tag &&
        segments[5] == assetName;
  }

  static bool _isGithubReleaseAssetUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }
    final segments = uri.pathSegments;
    return segments.length == 6 &&
        segments[0] == kGitHubOwner &&
        segments[1] == kGitHubRepo &&
        segments[2] == 'releases' &&
        segments[3] == 'download';
  }

  /// Compara duas versões semver. Retorna:
  /// - positivo se v1 > v2
  /// - negativo se v1 < v2
  /// - zero se iguais
  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Garante que ambos tenham pelo menos 3 partes
    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (parts1[i] > parts2[i]) return 1;
      if (parts1[i] < parts2[i]) return -1;
    }
    return 0;
  }

  /// Formata o tamanho do arquivo para exibição
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return 'Desconhecido';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
