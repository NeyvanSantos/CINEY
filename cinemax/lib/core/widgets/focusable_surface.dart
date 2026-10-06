import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';

class FocusableSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool autofocus;

  const FocusableSurface({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = BorderRadius.zero,
    this.autofocus = false,
  });

  @override
  State<FocusableSurface> createState() => _FocusableSurfaceState();
}

class _FocusableSurfaceState extends State<FocusableSurface> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (hasFocus) {
        if (_hasFocus != hasFocus) {
          setState(() => _hasFocus = hasFocus);
        }
      },
      autofocus: widget.autofocus,
      canRequestFocus: true,
      focusColor: Colors.transparent,
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          widget.child,
          if (_hasFocus)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    borderRadius: widget.borderRadius,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
