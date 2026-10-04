import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';

/// Card com efeito Glassmorphism
/// Usado em toda a UI para visual premium
class GlassCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: padding ?? const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor ?? AppColors.glassBackground,
                borderRadius: BorderRadius.circular(borderRadius),
                border: border ??
                    Border.all(
                      color: borderColor ?? Colors.white.withValues(alpha: borderOpacity),
                      width: borderWidth ?? 1,
                    ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.glassShadow,
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
