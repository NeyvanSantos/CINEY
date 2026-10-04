import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_logger.dart';

// ═══════════════════════════════════════════════════════════════
// CONFIGURE AQUI: Seu repositório GitHub público
// ═══════════════════════════════════════════════════════════════
const String kGitHubOwner = 'NeyvanSantos';
const String kGitHubRepo = 'CINEY';
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

  const AppUpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.releaseName,
    required this.fileSize,
    required this.hasUpdate,
    required this.htmlUrl,
  });
}

class AppUpdater {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'CineMax-Updater',
    },
  ));

  /// Verifica se existe uma atualização no GitHub Releases
  static Future<AppUpdateInfo?> checkForUpdates() async {
    try {
      AppLogger.info('Verificando atualizações no GitHub...', tag: 'UPDATER');

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await _dio.get(
        'https://api.github.com/repos/$kGitHubOwner/$kGitHubRepo/releases/latest',
      );

      if (response.statusCode != 200) {
        AppLogger.warn(
          'GitHub API retornou status ${response.statusCode}',
          tag: 'UPDATER',
        );
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String?) ?? '';
      final latestVersion = tagName.replaceFirst(RegExp(r'^v'), '');
      final releaseName = (data['name'] as String?) ?? 'Nova Atualização';
      final releaseNotes = (data['body'] as String?) ?? 'Sem notas de versão.';
      final htmlUrl = (data['html_url'] as String?) ?? '';
      final assets = (data['assets'] as List<dynamic>?) ?? [];

      // Procura o APK nos assets da release
      String downloadUrl = '';
      int fileSize = 0;
      for (final asset in assets) {
        final name = (asset['name'] as String?) ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          downloadUrl = (asset['browser_download_url'] as String?) ?? '';
          fileSize = (asset['size'] as int?) ?? 0;
          break;
        }
      }

      final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;

      AppLogger.info(
        'Versão atual: $currentVersion | Última: $latestVersion | '
        'Atualização: ${hasUpdate ? "SIM" : "NÃO"}',
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

  /// Baixa o APK com callback de progresso (0.0 a 1.0)
  static Future<File?> downloadApk(
    String downloadUrl, {
    required ValueChanged<double> onProgress,
  }) async {
    try {
      AppLogger.info('Iniciando download do APK...', tag: 'UPDATER');

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/cinemax_update.apk';

      // Remove APK antigo se existir
      final oldFile = File(filePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      await _dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );

      final file = File(filePath);
      if (await file.exists()) {
        final sizeInMb = (await file.length()) / (1024 * 1024);
        AppLogger.info(
          'Download completo! Tamanho: ${sizeInMb.toStringAsFixed(1)} MB',
          tag: 'UPDATER',
        );
        return file;
      }

      return null;
    } catch (e) {
      AppLogger.error('Erro ao baixar APK: $e', tag: 'UPDATER');
      return null;
    }
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
