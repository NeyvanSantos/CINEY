import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/widgets/focusable_surface.dart';
import '../../../../../plugin_engine/models/content_item.dart';
import '../../../../../plugin_engine/models/stream_source.dart';

class _MoveServerIntent extends Intent {
  final int direction;

  const _MoveServerIntent(this.direction);
}

class _SelectServerIntent extends Intent {
  const _SelectServerIntent();
}

class ServerSelectionSheet extends StatefulWidget {
  final ContentDetail item;
  final List<StreamSource> sources;
  final String? episodeText;
  final bool isTv;
  final int initialIndex;
  final ValueChanged<int> onSelect;

  const ServerSelectionSheet({
    super.key,
    required this.item,
    required this.sources,
    required this.isTv,
    required this.onSelect,
    this.episodeText,
    this.initialIndex = 0,
  });

  @override
  State<ServerSelectionSheet> createState() => _ServerSelectionSheetState();
}

class _ServerSelectionSheetState extends State<ServerSelectionSheet> {
  final GlobalKey _interactionAreaKey = GlobalKey();
  final FocusNode _keyboardFocusNode = FocusNode();
  late final List<GlobalKey> _sourceKeys;
  Timer? _cursorTimer;
  Offset? _cursorPosition;
  bool _cursorVisible = false;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, widget.sources.length - 1);
    _sourceKeys = List.generate(widget.sources.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isTv) _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.isTv || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _select(_selectedIndex);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveSelection(int direction) {
    final nextIndex = (_selectedIndex + direction)
        .clamp(0, widget.sources.length - 1)
        .toInt();
    if (nextIndex == _selectedIndex) {
      _showCursorAtSelectedSource();
      return;
    }
    setState(() => _selectedIndex = nextIndex);
    _showCursorAtSelectedSource();
  }

  void _showCursorAtSelectedSource() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final area = _interactionAreaKey.currentContext?.findRenderObject();
      final source = _sourceKeys[_selectedIndex].currentContext
          ?.findRenderObject();
      if (area is! RenderBox ||
          source is! RenderBox ||
          !area.hasSize ||
          !source.hasSize) {
        return;
      }
      final globalPosition = source.localToGlobal(
        source.size.center(Offset.zero),
      );
      _revealCursor(area.globalToLocal(globalPosition));
    });
  }

  int? _sourceAtGlobalPosition(Offset globalPosition) {
    for (var index = 0; index < _sourceKeys.length; index++) {
      final renderObject = _sourceKeys[index].currentContext
          ?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
      if (rect.contains(globalPosition)) return index;
    }
    return null;
  }

  void _handlePointerMove(Offset localPosition, Offset globalPosition) {
    if (!widget.isTv) return;
    final hoveredIndex = _sourceAtGlobalPosition(globalPosition);
    setState(() {
      _cursorPosition = localPosition;
      _cursorVisible = true;
      if (hoveredIndex != null) _selectedIndex = hoveredIndex;
    });
    _restartCursorTimer();
  }

  void _revealCursor(Offset position) {
    setState(() {
      _cursorPosition = position;
      _cursorVisible = true;
    });
    _restartCursorTimer();
  }

  void _restartCursorTimer() {
    _cursorTimer?.cancel();
    _cursorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _cursorVisible = false);
    });
  }

  void _select(int index) {
    if (index < 0 || index >= widget.sources.length) return;
    Navigator.of(context).pop();
    widget.onSelect(index);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      key: _interactionAreaKey,
      cursor: _cursorVisible
          ? SystemMouseCursors.none
          : SystemMouseCursors.basic,
      onHover: (event) =>
          _handlePointerMove(event.localPosition, event.position),
      child: Listener(
        onPointerMove: (event) =>
            _handlePointerMove(event.localPosition, event.position),
        child: Shortcuts(
          shortcuts: {
            SingleActivator(LogicalKeyboardKey.arrowUp):
                const _MoveServerIntent(-1),
            SingleActivator(LogicalKeyboardKey.arrowLeft):
                const _MoveServerIntent(-1),
            SingleActivator(LogicalKeyboardKey.arrowDown):
                const _MoveServerIntent(1),
            SingleActivator(LogicalKeyboardKey.arrowRight):
                const _MoveServerIntent(1),
            SingleActivator(LogicalKeyboardKey.select):
                const _SelectServerIntent(),
            SingleActivator(LogicalKeyboardKey.enter):
                const _SelectServerIntent(),
            SingleActivator(LogicalKeyboardKey.numpadEnter):
                const _SelectServerIntent(),
            SingleActivator(LogicalKeyboardKey.space):
                const _SelectServerIntent(),
          },
          child: Actions(
            actions: {
              _MoveServerIntent: CallbackAction<_MoveServerIntent>(
                onInvoke: (intent) {
                  if (widget.isTv) _moveSelection(intent.direction);
                  return null;
                },
              ),
              _SelectServerIntent: CallbackAction<_SelectServerIntent>(
                onInvoke: (_) {
                  if (widget.isTv) _select(_selectedIndex);
                  return null;
                },
              ),
            },
            child: Focus(
              focusNode: _keyboardFocusNode,
              autofocus: widget.isTv,
              onKeyEvent: _handleKeyEvent,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 44,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.dns_rounded,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Escolha o Servidor',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        widget.episodeText != null
                                            ? '${widget.item.title} • ${widget.episodeText}'
                                            : widget.item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white60,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            ...widget.sources.asMap().entries.map(_buildSource),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (widget.isTv && _cursorPosition != null)
                    Positioned(
                      left: _cursorPosition!.dx - 5,
                      top: _cursorPosition!.dy - 5,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _cursorVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: const Icon(
                            Icons.mouse_rounded,
                            color: Colors.white,
                            size: 28,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSource(MapEntry<int, StreamSource> entry) {
    final index = entry.key;
    final source = entry.value;
    final isEmbedMovies = source.server.contains('EmbedMovies');
    final isSuperFlix = source.server.contains('SuperFlix');
    final badgeText = isEmbedMovies
        ? 'Recomendado PT-BR'
        : (isSuperFlix ? 'Dublado 1080p' : source.quality);
    final badgeColor = isEmbedMovies || isSuperFlix
        ? const Color(0xFF10B981)
        : AppColors.primary;
    final isSelected = widget.isTv && _selectedIndex == index;

    return Container(
      key: _sourceKeys[index],
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : AppColors.surfaceVariant.withValues(alpha: 0.8),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: FocusableSurface(
        key: ValueKey(
          'server-option-$index-${isSelected ? "selected" : "idle"}',
        ),
        autofocus: !widget.isTv && index == 0,
        borderRadius: BorderRadius.circular(16),
        onTap: () => _select(index),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEmbedMovies
                      ? Icons.star_rounded
                      : (isSuperFlix
                            ? Icons.record_voice_over_rounded
                            : Icons.dns_rounded),
                  color: badgeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            source.server,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: badgeColor.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              badgeText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEmbedMovies
                          ? 'Dublado e Legendado • Player Adaptativo'
                          : (isSuperFlix
                                ? 'Dublado PT-BR • Full HD 1080p'
                                : '${source.quality} • ${source.isEmbed ? "Embed" : "Direto"}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
