import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/theme/app_colors.dart';

/// Widget de loading com efeito Shimmer
/// Usado enquanto conteúdo está carregando
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// Shimmer de card de poster (para carrosséis)
  static Widget poster({double width = 130, double height = 195}) {
    return ShimmerLoading(
      width: width,
      height: height,
      borderRadius: 12,
    );
  }

  /// Shimmer de linha de texto
  static Widget text({double width = 120, double height = 14}) {
    return ShimmerLoading(
      width: width,
      height: height,
      borderRadius: 6,
    );
  }

  /// Shimmer do hero banner
  static Widget heroBanner() {
    return const ShimmerLoading(
      width: double.infinity,
      height: 400,
      borderRadius: 0,
    );
  }

  /// Shimmer de carrossel horizontal completo
  static Widget carousel() {
    return SizedBox(
      height: 230,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerLoading.text(width: 150, height: 18),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => ShimmerLoading.poster(),
            ),
          ),
        ],
      ),
    );
  }
}
