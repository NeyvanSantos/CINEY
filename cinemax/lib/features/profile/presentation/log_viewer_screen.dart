import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/widgets/focusable_surface.dart';
import '../../auth/services/account_repository.dart';
import '../services/diagnostic_report_service.dart';

class LogViewerScreen extends ConsumerStatefulWidget {
  const LogViewerScreen({super.key});

  @override
  ConsumerState<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends ConsumerState<LogViewerScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _reportDescriptionController =
      TextEditingController();
  bool _autoScroll = true;
  bool _isSendingReport = false;
  LogLevel? _filterLevel;
  String _searchQuery = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _reportDescriptionController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _copyAll(List<LogEntry> entries) async {
    final text = entries.map((e) => e.toString()).join('\n');
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (error, stack) {
      AppLogger.error(
        'Falha ao copiar logs: $error',
        tag: 'SYSTEM',
        stackTrace: stack,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível copiar os logs.')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${entries.length} linha(s) copiada(s) para a área de transferência!',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A7A4A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _reportNow(List<LogEntry> entries) async {
    if (entries.isEmpty || _isSendingReport) return;
    _reportDescriptionController.clear();
    final description = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Enviar relatório de diagnóstico?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entries.length} logs desta sessão serão enviados, incluindo erros e stack traces. O app mascara e-mails, credenciais e parâmetros de URLs, mas mensagens podem conter termos digitados ou outros dados. Revise o Console antes de autorizar.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reportDescriptionController,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'O que aconteceu? (opcional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(dialogContext, _reportDescriptionController.text),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (description == null || !mounted) return;

    final platform = Theme.of(context).platform.name.toLowerCase();
    setState(() => _isSendingReport = true);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final reportId =
          await DiagnosticReportService(
            ref.read(supabaseClientProvider),
          ).submit(
            entries: AppLogger.entries,
            description: description,
            appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
            platform: platform,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Relatório enviado. Protocolo: $reportId')),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Falha ao enviar relatório de diagnóstico: $error',
        tag: 'DIAGNOSTICS',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível enviar o relatório: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSendingReport = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  List<LogEntry> _applyFilters(List<LogEntry> all) {
    return all.where((e) {
      if (_filterLevel != null && e.level != _filterLevel) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return e.message.toLowerCase().contains(q) ||
            e.tag.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return const Color(0xFF8A8A9A);
      case LogLevel.info:
        return const Color(0xFF4DA6FF);
      case LogLevel.warning:
        return const Color(0xFFFFB347);
      case LogLevel.error:
        return const Color(0xFFFF5566);
      case LogLevel.success:
        return const Color(0xFF4ADE80);
    }
  }

  IconData _levelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Icons.bug_report_outlined;
      case LogLevel.info:
        return Icons.info_outline_rounded;
      case LogLevel.warning:
        return Icons.warning_amber_rounded;
      case LogLevel.error:
        return Icons.error_outline_rounded;
      case LogLevel.success:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(appLogProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1120),
        elevation: 0,
        title: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF4ADE80,
                  ).withValues(alpha: _pulseAnim.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF4ADE80,
                      ).withValues(alpha: _pulseAnim.value * 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('Console de Logs', style: AppTypography.headlineMedium),
          ],
        ),
        actions: [
          // Botão auto-scroll
          Tooltip(
            message: 'Auto-scroll: ${_autoScroll ? "ON" : "OFF"}',
            child: IconButton(
              icon: Icon(
                Icons.vertical_align_bottom_rounded,
                color: _autoScroll ? AppColors.primary : AppColors.textTertiary,
              ),
              onPressed: () => setState(() => _autoScroll = !_autoScroll),
            ),
          ),
          // Botão limpar
          Tooltip(
            message: 'Limpar todos os logs',
            child: IconButton(
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: AppColors.textTertiary,
              ),
              onPressed: () {
                AppLogger.clear();
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _buildFilterBar(),
        ),
      ),
      body: logsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text(
            'Erro ao carregar logs: $e',
            style: const TextStyle(color: AppColors.textTertiary),
          ),
        ),
        data: (allLogs) {
          final filtered = _applyFilters(allLogs);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _autoScroll) _scrollToBottom();
          });

          return Column(
            children: [
              // Barra de pesquisa dentro dos logs
              _buildSearchBar(),

              // Cabeçalho de contagem
              _buildLogHeader(allLogs.length, filtered.length),

              // Lista de logs
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildLogEntry(filtered[index], index);
                        },
                      ),
              ),

              // Bottom bar: COPIAR TUDO
              _buildBottomBar(allLogs, filtered),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    final levels = [
      null,
      LogLevel.debug,
      LogLevel.info,
      LogLevel.warning,
      LogLevel.error,
      LogLevel.success,
    ];
    final labels = ['Todos', 'Debug', 'Info', 'Aviso', 'Erro', 'OK'];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: levels.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final isSelected = _filterLevel == levels[i];
          final color = levels[i] != null
              ? _levelColor(levels[i]!)
              : AppColors.primary;

          return FocusableSurface(
            onTap: () => setState(() => _filterLevel = levels[i]),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : const Color(0xFF2A2D40),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                  color: isSelected ? color : AppColors.textTertiary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Filtrar por mensagem ou tag...',
          hintStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textTertiary,
            size: 18,
          ),
          filled: true,
          fillColor: const Color(0xFF141828),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2A2D40)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2A2D40)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogHeader(int total, int filtered) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Text(
            '$filtered de $total entradas',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          if (_filterLevel != null || _searchQuery.isNotEmpty)
            FocusableSurface(
              onTap: () => setState(() {
                _filterLevel = null;
                _searchQuery = '';
                _searchController.clear();
              }),
              borderRadius: BorderRadius.circular(4),
              child: const Row(
                children: [
                  Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Limpar filtros',
                    style: TextStyle(fontSize: 11, color: AppColors.primary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(LogEntry entry, int index) {
    final color = _levelColor(entry.level);
    final icon = _levelIcon(entry.level);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: index % 2 == 0
            ? const Color(0xFF0E1220)
            : const Color(0xFF0A0E18),
        border: Border(left: BorderSide(color: color, width: 2)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone do nível
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha de cabeçalho: horário + tag
                Row(
                  children: [
                    Text(
                      entry.formattedTime,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                        fontFamily: 'monospace',
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        entry.tag,
                        style: TextStyle(
                          fontSize: 9,
                          color: color,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Mensagem do log
                SelectableText(
                  entry.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: entry.level == LogLevel.error
                        ? const Color(0xFFFF5566)
                        : entry.level == LogLevel.warning
                        ? const Color(0xFFFFD080)
                        : const Color(0xFFDDE1F0),
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.terminal_rounded,
            size: 56,
            color: Color(0xFF2A2D40),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum log registrado',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Os eventos do app aparecem aqui em tempo real\nassim que ocorrem.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(List<LogEntry> allLogs, List<LogEntry> filtered) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1120),
        border: Border(top: BorderSide(color: Color(0xFF1E2235), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'CINEMAX LOG CONSOLE',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textTertiary,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      '${allLogs.length} entrada(s) na sessão',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: allLogs.isEmpty || _isSendingReport
                    ? null
                    : () => _reportNow(allLogs),
                icon: _isSendingReport
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.outgoing_mail, size: 17),
                label: Text(_isSendingReport ? 'Enviando' : 'Reportar agora'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: filtered.isEmpty ? null : () => _copyAll(filtered),
              icon: const Icon(Icons.copy_all_rounded, size: 17),
              label: const Text('Copiar Tudo'),
            ),
          ),
        ],
      ),
    );
  }
}
