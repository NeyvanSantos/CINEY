import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/widgets/focusable_surface.dart';

class MainNavScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final bool isTv;

  const MainNavScreen({
    super.key,
    required this.navigationShell,
    this.isTv = false,
  });

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  final List<FocusNode> _tvNavigationFocusNodes = List.generate(
    4,
    (index) => FocusNode(debugLabel: 'TV navigation destination $index'),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isTv) {
        _tvNavigationFocusNodes[widget.navigationShell.currentIndex]
            .requestFocus();
      }
    });
  }

  StatefulNavigationShell get navigationShell => widget.navigationShell;
  bool get isTv => widget.isTv;

  @override
  void dispose() {
    for (final node in _tvNavigationFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleTvRailKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final nextIndex = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => (index + 1).clamp(0, 3),
      LogicalKeyboardKey.arrowUp => (index - 1).clamp(0, 3),
      _ => null,
    };
    if (nextIndex != null) {
      _tvNavigationFocusNodes[nextIndex].requestFocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      return FocusManager.instance.primaryFocus?.focusInDirection(
                TraversalDirection.right,
              ) ==
              true
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleTvContentKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    final movedWithinContent =
        FocusManager.instance.primaryFocus?.focusInDirection(
          TraversalDirection.left,
        ) ??
        false;
    if (movedWithinContent) return KeyEventResult.handled;
    _tvNavigationFocusNodes[navigationShell.currentIndex].requestFocus();
    return KeyEventResult.handled;
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    if (isTv) {
      final isExtended = MediaQuery.sizeOf(context).width >= 1200;
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Row(
              children: [
                SizedBox(
                  width: isExtended ? 192 : 88,
                  child: Material(
                    color: AppColors.navBackground,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTvNavItem(
                            destinationIndex: 0,
                            icon: Iconsax.home_2,
                            activeIcon: Iconsax.home_21,
                            label: 'Início',
                            isSelected: currentIndex == 0,
                            autofocus: currentIndex == 0,
                            extended: isExtended,
                            onTap: () => _onTap(0),
                          ),
                          _buildTvNavItem(
                            destinationIndex: 1,
                            icon: Iconsax.search_normal_1,
                            activeIcon: Iconsax.search_normal_11,
                            label: 'Buscar',
                            isSelected: currentIndex == 1,
                            autofocus: currentIndex == 1,
                            extended: isExtended,
                            onTap: () => _onTap(1),
                          ),
                          _buildTvNavItem(
                            destinationIndex: 2,
                            icon: Iconsax.receive_square_2,
                            activeIcon: Iconsax.receive_square_21,
                            label: 'Downloads',
                            isSelected: currentIndex == 2,
                            autofocus: currentIndex == 2,
                            extended: isExtended,
                            onTap: () => _onTap(2),
                          ),
                          _buildTvNavItem(
                            destinationIndex: 3,
                            icon: Iconsax.setting_2,
                            activeIcon: Iconsax.setting_21,
                            label: 'Perfil',
                            isSelected: currentIndex == 3,
                            autofocus: currentIndex == 3,
                            extended: isExtended,
                            onTap: () => _onTap(3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                Expanded(
                  child: Focus(
                    onKeyEvent: (_, event) => _handleTvContentKey(event),
                    child: navigationShell,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.navBackground,
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _buildNavItem(
                  icon: Iconsax.home_2,
                  activeIcon: Iconsax.home_21,
                  label: 'Início',
                  isSelected: currentIndex == 0,
                  onTap: () => _onTap(0),
                ),
                _buildNavItem(
                  icon: Iconsax.search_normal_1,
                  activeIcon: Iconsax.search_normal_11,
                  label: 'Buscar',
                  isSelected: currentIndex == 1,
                  onTap: () => _onTap(1),
                ),
                _buildNavItem(
                  icon: Iconsax.receive_square_2,
                  activeIcon: Iconsax.receive_square_21,
                  label: 'Downloads',
                  isSelected: currentIndex == 2,
                  onTap: () => _onTap(2),
                ),
                _buildNavItem(
                  icon: Iconsax.setting_2,
                  activeIcon: Iconsax.setting_21,
                  label: 'Perfil',
                  isSelected: currentIndex == 3,
                  onTap: () => _onTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTvNavItem({
    required int destinationIndex,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required bool autofocus,
    required bool extended,
    required VoidCallback onTap,
  }) {
    return Focus(
      onKeyEvent: (_, event) => _handleTvRailKey(destinationIndex, event),
      child: FocusableSurface(
        autofocus: autofocus,
        focusNode: _tvNavigationFocusNodes[destinationIndex],
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: extended ? 176 : 80,
          height: extended ? 56 : 64,
          child: extended
              ? Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(
                      isSelected ? activeIcon : icon,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textTertiary,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? activeIcon : icon,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textTertiary,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                width: 52,
                height: 30,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Center(
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textTertiary,
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  letterSpacing: 0.2,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
