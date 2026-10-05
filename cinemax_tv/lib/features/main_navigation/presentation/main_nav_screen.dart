import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/config/theme/app_colors.dart';

class MainNavScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavScreen({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;
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
}
