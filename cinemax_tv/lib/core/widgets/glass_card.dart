import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';

/// Card com efeito Glassmorphism
/// Usado em toda a UI para visual premium
class GlassCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final double borderOpacity;
  final BoxBorder? border;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
    this.margin,
    this.blur = 20,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderOpacity = 0.08,
    this.border,
    this.onTap,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: InkWell(
            onTap: widget.onTap,
            canRequestFocus: widget.onTap != null,
            onFocusChange: (focused) {
              if (_isFocused != focused) setState(() => _isFocused = focused);
            },
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: widget.padding ?? const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? AppColors.glassBackground,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: _isFocused
                    ? Border.all(color: AppColors.primary, width: 2)
                    : widget.border ??
                          Border.all(
                            color:
                                widget.borderColor ??
                                Colors.white.withValues(
                                  alpha: widget.borderOpacity,
                                ),
                            width: widget.borderWidth ?? 1,
                          ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.glassShadow,
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
