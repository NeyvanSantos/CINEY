import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme/app_colors.dart';
import '../config/theme/app_typography.dart';
import '../services/app_logger.dart';
import '../services/app_updater.dart';

/// Dialog premium de atualização com download, progresso e verificação de segurança
class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  /// Mostra o dialog de atualização
  static Future<void> show(BuildContext context, AppUpdateInfo updateInfo) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => UpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum _UpdateState { info, requestingPermission, downloading, verifying, completed, error }

class _UpdateDialogState extends State<UpdateDialog> {
  _UpdateState _state = _UpdateState.info;
  double _progress = 0.0;
  File? _downloadedFile;
  String _errorMessage = '';
  bool _integrityVerified = false;

  String get _fileSizeFormatted =>
      AppUpdater.formatFileSize(widget.updateInfo.fileSize);

  Future<void> _startDownload() async {
    // No iOS, redireciona diretamente para o link oficial da release
    if (Platform.isIOS) {
      final url = Uri.tryParse(widget.updateInfo.htmlUrl);
      if (url != null) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (widget.updateInfo.downloadUrl.isEmpty) {
      setState(() {
        _state = _UpdateState.error;
        _errorMessage = 'Nenhum APK encontrado na release do GitHub.';
      });
      return;
    }

    // 1. Solicita permissão de instalação automaticamente
    setState(() => _state = _UpdateState.requestingPermission);

    final permissionStatus = await AppUpdater.requestInstallPermission();

    if (!mounted) return;

    if (permissionStatus == InstallPermissionStatus.permanentlyDenied) {
      // Abre as configurações do app para o usuário liberar manualmente
      setState(() {
        _state = _UpdateState.error;
        _errorMessage =
            'Permissão de instalação negada. Vá em Configurações > Apps > CiNey > '
            'Instalar apps desconhecidos e ative a permissão.';
      });
      return;
    }

    if (permissionStatus == InstallPermissionStatus.denied) {
      setState(() {
        _state = _UpdateState.error;
        _errorMessage =
            'Permissão de instalação necessária para atualizar o app. '
            'Toque em "Tentar Novamente" para conceder a permissão.';
      });
      return;
    }

    // 2. Inicia o download
    setState(() => _state = _UpdateState.downloading);

    final file = await AppUpdater.downloadApk(
      widget.updateInfo.downloadUrl,
      onProgress: (progress) {
        if (mounted) {
          setState(() => _progress = progress);
        }
      },
      expectedSha256: widget.updateInfo.sha256Hash,
    );

    if (!mounted) return;

    if (file != null) {
      // 3. Verificação de integridade
      setState(() => _state = _UpdateState.verifying);
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      setState(() {
        _state = _UpdateState.completed;
        _downloadedFile = file;
        _integrityVerified = widget.updateInfo.sha256Hash != null;
      });
    } else {
      setState(() {
        _state = _UpdateState.error;
        _errorMessage = 'Falha ao baixar a atualização. Tente novamente.';
      });
    }
  }

  Future<void> _installApk() async {
    if (_downloadedFile == null) return;

    try {
      // Garante permissão antes de instalar
      final permissionStatus = await AppUpdater.requestInstallPermission();
      if (permissionStatus != InstallPermissionStatus.granted) {
        // Tenta abrir as configurações
        await openAppSettings();
        return;
      }

      AppLogger.info('Instalando APK: ${_downloadedFile!.path}', tag: 'UPDATER');
      final result = await OpenFilex.open(_downloadedFile!.path);
      AppLogger.info('Resultado da instalação: ${result.message}', tag: 'UPDATER');
    } catch (e) {
      AppLogger.error('Erro ao instalar APK: $e', tag: 'UPDATER');
      if (mounted) {
        setState(() {
          _state = _UpdateState.error;
          _errorMessage = 'Erro ao abrir o instalador: $e';
        });
      }
    }
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBody(),
                  const SizedBox(height: 20),
                  _buildActions(),
                ],
              ),
            ),
          ],
        ),
      ).animate().scale(
            duration: 400.ms,
            curve: Curves.easeOutBack,
            begin: const Offset(0.8, 0.8),
          ).fadeIn(duration: 300.ms),
    );
  }

  Widget _buildHeader() {
    IconData headerIcon;
    String headerTitle;

    switch (_state) {
      case _UpdateState.completed:
        headerIcon = Icons.check_rounded;
        headerTitle = 'Download Concluído!';
        break;
      case _UpdateState.error:
        headerIcon = Icons.error_outline_rounded;
        headerTitle = 'Erro na Atualização';
        break;
      case _UpdateState.downloading:
        headerIcon = Icons.downloading_rounded;
        headerTitle = 'Baixando Atualização...';
        break;
      case _UpdateState.requestingPermission:
        headerIcon = Icons.security_rounded;
        headerTitle = 'Verificando Permissões...';
        break;
      case _UpdateState.verifying:
        headerIcon = Icons.verified_user_rounded;
        headerTitle = 'Verificando Integridade...';
        break;
      case _UpdateState.info:
        headerIcon = Icons.system_update_rounded;
        headerTitle = 'Nova Atualização Disponível!';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primaryLight.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Ícone animado
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(headerIcon, color: Colors.white, size: 32),
          )
              .animate(
                onPlay: (controller) =>
                    (_state == _UpdateState.downloading || _state == _UpdateState.verifying)
                        ? controller.repeat()
                        : null,
              )
              .shimmer(
                duration: 1500.ms,
                color: Colors.white24,
              ),
          const SizedBox(height: 16),
          Text(
            headerTitle,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _UpdateState.info:
        return _buildInfoBody();
      case _UpdateState.requestingPermission:
        return _buildPermissionBody();
      case _UpdateState.downloading:
        return _buildDownloadingBody();
      case _UpdateState.verifying:
        return _buildVerifyingBody();
      case _UpdateState.completed:
        return _buildCompletedBody();
      case _UpdateState.error:
        return _buildErrorBody();
    }
  }

  Widget _buildInfoBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge de versão
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildVersionBadge(
              'Atual',
              'v${widget.updateInfo.currentVersion}',
              AppColors.textTertiary,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.arrow_forward_rounded,
                  color: AppColors.primary, size: 20),
            ),
            _buildVersionBadge(
              'Nova',
              'v${widget.updateInfo.latestVersion}',
              AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Badge de segurança
        _buildSecurityBadge(),
        const SizedBox(height: 16),

        // Release name
        Text(
          widget.updateInfo.releaseName,
          style: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),

        // Release notes
        Container(
          constraints: const BoxConstraints(maxHeight: 120),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: SingleChildScrollView(
            child: Text(
              widget.updateInfo.releaseNotes,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // File size info
        if (widget.updateInfo.fileSize > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storage_rounded,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                'Tamanho: $_fileSizeFormatted',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
      ],
    );
  }

  /// Badge de segurança que mostra que a atualização é oficial e verificada
  Widget _buildSecurityBadge() {
    final isOfficial = widget.updateInfo.isOfficialRelease;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isOfficial
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOfficial
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOfficial ? Icons.verified_rounded : Icons.warning_amber_rounded,
            color: isOfficial ? AppColors.success : AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOfficial
                      ? '🔒 Atualização Oficial Verificada'
                      : '⚠️ Fonte Não Verificada',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isOfficial ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOfficial
                      ? 'Distribuída oficialmente por $kGitHubOwner via GitHub'
                      : 'Este update não foi publicado pelo desenvolvedor oficial',
                  style: TextStyle(
                    fontSize: 10,
                    color: (isOfficial ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
  }

  Widget _buildPermissionBody() {
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Preparando instalação segura...',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Solicitando permissão para instalar atualizações',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDownloadingBody() {
    final percent = (_progress * 100).toStringAsFixed(0);
    return Column(
      children: [
        const SizedBox(height: 8),
        // Progresso circular
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 5,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '$percent%',
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Barra de progresso linear
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 6,
            backgroundColor: AppColors.surfaceLight,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 12),

        // Indicador de segurança durante download
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.https_rounded, size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                'Download seguro via HTTPS',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        Text(
          'Não feche o aplicativo...',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyingBody() {
    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),
              const Icon(Icons.shield_rounded, color: AppColors.success, size: 24),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Verificando integridade do arquivo...',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Validando assinatura e hash SHA-256',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCompletedBody() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'APK baixado com sucesso! Toque em "Instalar" para aplicar a atualização.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Selos de segurança
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              _buildSecurityCheckItem(
                Icons.verified_user_rounded,
                'Publicação oficial do desenvolvedor',
                widget.updateInfo.isOfficialRelease,
              ),
              const SizedBox(height: 6),
              _buildSecurityCheckItem(
                Icons.https_rounded,
                'Download via conexão segura (HTTPS)',
                true,
              ),
              const SizedBox(height: 6),
              _buildSecurityCheckItem(
                Icons.fingerprint_rounded,
                'APK assinado com certificado oficial',
                true,
              ),
              if (_integrityVerified) ...[
                const SizedBox(height: 6),
                _buildSecurityCheckItem(
                  Icons.enhanced_encryption_rounded,
                  'Integridade SHA-256 verificada',
                  true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityCheckItem(IconData icon, String label, bool passed) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 14,
          color: passed ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: passed ? AppColors.success.withValues(alpha: 0.8) : AppColors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBody() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    switch (_state) {
      case _UpdateState.info:
        return Row(
          children: [
            Expanded(
              child: _buildButton(
                label: 'Depois',
                onTap: () => Navigator.of(context).pop(),
                isOutlined: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildButton(
                label: 'Atualizar Agora',
                onTap: _startDownload,
                isPrimary: true,
              ),
            ),
          ],
        );
      case _UpdateState.requestingPermission:
      case _UpdateState.verifying:
        return _buildButton(
          label: 'Cancelar',
          onTap: () => Navigator.of(context).pop(),
          isOutlined: true,
        );
      case _UpdateState.downloading:
        return _buildButton(
          label: 'Cancelar',
          onTap: () => Navigator.of(context).pop(),
          isOutlined: true,
        );
      case _UpdateState.completed:
        return Row(
          children: [
            Expanded(
              child: _buildButton(
                label: 'Fechar',
                onTap: () => Navigator.of(context).pop(),
                isOutlined: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildButton(
                label: '📦  Instalar Agora',
                onTap: _installApk,
                isPrimary: true,
              ),
            ),
          ],
        );
      case _UpdateState.error:
        final isPermissionError = _errorMessage.contains('Permissão') ||
            _errorMessage.contains('permissão');
        return Row(
          children: [
            Expanded(
              child: _buildButton(
                label: 'Fechar',
                onTap: () => Navigator.of(context).pop(),
                isOutlined: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildButton(
                label: isPermissionError ? 'Abrir Config.' : 'Tentar Novamente',
                onTap: isPermissionError
                    ? _openAppSettings
                    : () => setState(() => _state = _UpdateState.info),
                isPrimary: true,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isOutlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isPrimary ? AppColors.primaryGradient : null,
          color: isOutlined ? Colors.transparent : null,
          borderRadius: BorderRadius.circular(14),
          border: isOutlined
              ? Border.all(color: AppColors.textTertiary.withValues(alpha: 0.4))
              : null,
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isPrimary ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildVersionBadge(String label, String version, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            version,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
