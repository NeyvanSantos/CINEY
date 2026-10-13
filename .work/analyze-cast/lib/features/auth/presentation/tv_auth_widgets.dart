import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';

/// Card de escolha otimizado para TV (10-foot experience) com foco D-Pad ultra-visível.
class TvChoiceCard extends StatefulWidget {
  const TvChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
    this.badge,
    this.focusNode,
    this.autofocus = false,
    this.onKey,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final String? badge;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final KeyEventResult Function(KeyEvent event)? onKey;

  @override
  State<TvChoiceCard> createState() => _TvChoiceCardState();
}

class _TvChoiceCardState extends State<TvChoiceCard> {
  late final FocusNode _node;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode(debugLabel: widget.title);
    _node.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _node.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _node.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    final hasFocus = _node.hasFocus;
    if (_hasFocus != hasFocus) {
      setState(() => _hasFocus = hasFocus);
      if (hasFocus) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (widget.onKey != null) {
      final customResult = widget.onKey!(event);
      if (customResult != KeyEventResult.ignored) return customResult;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onTap();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _hasFocus ? AppColors.primary : AppColors.glassBorder;
    final borderWidth = _hasFocus ? 3.5 : 1.5;

    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: (_, event) => _handleKeyEvent(event),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hasFocus ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: _hasFocus
                  ? AppColors.surface.withValues(alpha: 0.95)
                  : AppColors.surface.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: _hasFocus
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _hasFocus
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.badge!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _hasFocus ? Colors.black : AppColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else
                  const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _hasFocus
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    size: 48,
                    color: _hasFocus ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: AppTypography.headlineLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _hasFocus ? AppColors.primary : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  widget.subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: _hasFocus ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasFocus ? AppColors.primary : AppColors.glassBorder,
                      width: 1.5,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.buttonLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: _hasFocus ? Colors.black : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: _hasFocus ? Colors.black : AppColors.textPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Container com realce de foco e navegação D-Pad em campos de formulário para TV.
class TvFormFieldFocusContainer extends StatefulWidget {
  const TvFormFieldFocusContainer({
    super.key,
    required this.child,
    required this.focusNode,
    this.onDownPressed,
    this.onUpPressed,
  });

  final Widget child;
  final FocusNode focusNode;
  final VoidCallback? onDownPressed;
  final VoidCallback? onUpPressed;

  @override
  State<TvFormFieldFocusContainer> createState() =>
      _TvFormFieldFocusContainerState();
}

class _TvFormFieldFocusContainerState extends State<TvFormFieldFocusContainer> {
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocus);
    super.dispose();
  }

  void _handleFocus() {
    if (!mounted) return;
    final hasFocus = widget.focusNode.hasFocus;
    if (_hasFocus != hasFocus) {
      setState(() => _hasFocus = hasFocus);
      if (hasFocus) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        widget.onDownPressed != null) {
      widget.onDownPressed!();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        widget.onUpPressed != null) {
      widget.onUpPressed!();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) => _handleKey(event),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: _hasFocus
              ? Border.all(color: AppColors.primary, width: 3)
              : Border.all(color: Colors.transparent, width: 3),
          boxShadow: _hasFocus
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Botão com foco destacado e suporte a Select/Enter para D-Pad da TV.
class TvFocusableButton extends StatefulWidget {
  const TvFocusableButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.onDownPressed,
    this.onUpPressed,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onDownPressed;
  final VoidCallback? onUpPressed;

  @override
  State<TvFocusableButton> createState() => _TvFocusableButtonState();
}

class _TvFocusableButtonState extends State<TvFocusableButton> {
  late final FocusNode _node;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode();
    _node.addListener(_handleFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_handleFocus);
    if (widget.focusNode == null) {
      _node.dispose();
    }
    super.dispose();
  }

  void _handleFocus() {
    if (!mounted) return;
    final hasFocus = _node.hasFocus;
    if (_hasFocus != hasFocus) {
      setState(() => _hasFocus = hasFocus);
      if (hasFocus) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        widget.onDownPressed != null) {
      widget.onDownPressed!();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        widget.onUpPressed != null) {
      widget.onUpPressed!();
      return KeyEventResult.handled;
    }

    if (widget.onPressed != null &&
        (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      widget.onPressed!();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: (_, event) => _handleKey(event),
      child: AnimatedScale(
        scale: _hasFocus ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: _hasFocus
                ? Border.all(color: AppColors.primary, width: 3)
                : Border.all(color: Colors.transparent, width: 3),
            boxShadow: _hasFocus
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
