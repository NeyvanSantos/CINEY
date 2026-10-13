import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../plugin_engine/models/content_item.dart';
import '../../auth/services/account_messages.dart';
import '../../auth/services/account_repository.dart';
import '../services/favorites_repository.dart';

class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({super.key, required this.item});

  factory FavoriteButton.fromDetail({
    Key? key,
    required ContentDetail detail,
  }) => FavoriteButton(
    key: key,
    item: ContentItem(
      id: detail.id,
      title: detail.title,
      posterUrl: detail.posterUrl,
      type: detail.type,
      pluginId: detail.pluginId,
    ),
  );

  final ContentItem item;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  bool _saving = false;

  Future<void> _toggle(bool saved) async {
    final user = ref.read(accountUserProvider).valueOrNull;
    if (user == null) {
      await context.push('/auth');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(favoritesRepositoryProvider)
          .setFavorite(user.id, widget.item, saved: !saved);
      if (!mounted ||
          ref.read(accountUserProvider).valueOrNull?.id != user.id) {
        return;
      }
      // Re-query after the write, even when Realtime is unavailable/reconnecting.
      ref.invalidate(favoritesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Removido dos favoritos.' : 'Adicionado aos favoritos.',
          ),
        ),
      );
    } catch (error) {
      final message = accountErrorMessage(error);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountUserProvider);
    final favorites = ref.watch(favoritesProvider);
    final signedIn = account.valueOrNull != null;
    final loading =
        _saving || account.isLoading || (signedIn && favorites.isLoading);
    final saved =
        favorites.valueOrNull?.any(
          (item) => isSameContent(item, widget.item),
        ) ??
        false;
    return IconButton.filledTonal(
      tooltip: signedIn && favorites.hasError
          ? 'Recarregar favoritos'
          : saved
          ? 'Remover dos favoritos'
          : 'Favoritar',
      style: IconButton.styleFrom(backgroundColor: AppColors.surfaceLight),
      onPressed: loading
          ? null
          : () {
              if (signedIn && favorites.hasError) {
                ref.invalidate(favoritesProvider);
              } else {
                _toggle(saved);
              }
            },
      icon: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              favorites.hasError && signedIn
                  ? Icons.refresh
                  : saved
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: saved ? AppColors.primary : AppColors.textPrimary,
            ),
    );
  }
}
