import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme/app_colors.dart';
import '../config/theme/app_typography.dart';
import 'shimmer_loading.dart';

/// Card de poster de filme/série com gradiente overlay
/// Mostra poster, título, nota e tipo
class GradientPoster extends StatefulWidget {
  final String title;
  final String posterUrl;
  final double? rating;
  final String? year;
  final String? type; // 'movie' | 'series' | 'anime'
  final double width;
  final double height;
  final VoidCallback? onTap;

  const GradientPoster({
    super.key,
    required this.title,
    required this.posterUrl,
    this.rating,
    this.year,
    this.type,
    this.width = 180,
    this.height = 270,
    this.onTap,
  });

  @override
  State<GradientPoster> createState() => _GradientPosterState();
}

class _GradientPosterState extends State<GradientPoster> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (focused) {
        if (_isFocused != focused) setState(() => _isFocused = focused);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: widget.width,
        height: widget.height,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: _isFocused
              ? Border.all(color: AppColors.primary, width: 3)
              : null,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster Image
              CachedNetworkImage(
                imageUrl: widget.posterUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => ShimmerLoading.poster(
                  width: widget.width,
                  height: widget.height,
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surfaceVariant,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.movie_outlined,
                        color: AppColors.textTertiary,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          widget.title,
                          style: AppTypography.labelSmall,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Gradient overlay (bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: widget.height * 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // Rating badge (top-right)
              if (widget.rating != null && widget.rating! > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.ratingGold,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          widget.rating!.toStringAsFixed(1),
                          style: AppTypography.rating.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),

              // Title & Year (bottom)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.labelMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.year != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.year!,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
