import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/config/theme/app_colors.dart';

class MainNavScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final bool isTv;

  const MainNavScreen({
    super.key,
    required this.navigationShell,
    this.isTv = false,
  });

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
          child: Row(
            children: [
              NavigationRail(
                backgroundColor: AppColors.navBackground,
                selectedIndex: currentIndex,
                onDestinationSelected: _onTap,
                extended: isExtended,
                labelType: isExtended ? null : NavigationRailLabelType.all,
                minWidth: 88,
                minExtendedWidth: 192,
                groupAlignment: -0.55,
                selectedIconTheme: const IconThemeData(
                  color: AppColors.primary,
                  size: 26,
                ),
                unselectedIconTheme: const IconThemeData(
                  color: AppColors.textTertiary,
                  size: 24,
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Iconsax.home_2),
                    selectedIcon: Icon(Iconsax.home_21),
                    label: Text('Início'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Iconsax.search_normal_1),
                    selectedIcon: Icon(Iconsax.search_normal_11),
                    label: Text('Buscar'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Iconsax.receive_square_2),
                    selectedIcon: Icon(Iconsax.receive_square_21),
                    label: Text('Downloads'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Iconsax.setting_2),
                    selectedIcon: Icon(Iconsax.setting_21),
                    label: Text('Perfil'),
                  ),
                ],
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Expanded(child: navigationShell),
            ],
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
