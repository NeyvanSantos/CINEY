import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Downloads', style: AppTypography.headlineLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded),
            tooltip: 'Limpar todos',
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de Armazenamento
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Armazenamento do Dispositivo', style: AppTypography.labelLarge),
                      const Text(
                        '12.4 GB livres de 128 GB',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      value: 0.25,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text('Itens Salvos', style: AppTypography.headlineMedium),
            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                children: [
                  _buildDownloadItem(
                    title: 'Duna: Parte 2 (2024)',
                    size: '2.1 GB • 1080p FHD',
                    progress: 1.0,
                    isCompleted: true,
                    posterUrl: 'https://image.tmdb.org/t/p/w500/8b8R8l88Qje9dn9OE8PY05Nxl1X.jpg',
                  ),
                  const SizedBox(height: 12),
                  _buildDownloadItem(
                    title: 'Demon Slayer: Episódio 1',
                    size: '450 MB • 720p HD',
                    progress: 0.65,
                    isCompleted: false,
                    posterUrl: 'https://image.tmdb.org/t/p/w500/xUfRZu2mi8jH6SzQEJGP6tjBuYj.jpg',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadItem({
    required String title,
    required String size,
    required double progress,
    required bool isCompleted,
    required String posterUrl,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              posterUrl,
              width: 50,
              height: 70,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 50,
                height: 70,
                color: AppColors.surfaceVariant,
                child: const Icon(Icons.movie, color: AppColors.textTertiary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(size, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                const SizedBox(height: 8),
                if (!isCompleted)
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 4,
                  )
                else
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                      SizedBox(width: 4),
                      Text('Pronto para assistir offline', style: TextStyle(fontSize: 11, color: AppColors.success)),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isCompleted ? Iconsax.play_circle : Iconsax.pause_circle,
              color: AppColors.primary,
              size: 28,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
