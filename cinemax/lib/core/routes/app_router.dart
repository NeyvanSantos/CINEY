import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/details/presentation/details_screen.dart';
import '../../features/downloads/presentation/downloads_screen.dart';
import '../../features/extensions/presentation/extensions_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/catalog_section_screen.dart';
import '../../features/main_navigation/presentation/main_nav_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/profile/presentation/log_viewer_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../plugin_engine/models/content_item.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    // Splash Screen
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),

    // Onboarding / Setup Inicial (Idioma e Fontes)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    // Stateful Navigation Shell (Bottom Navigation Bar)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainNavScreen(navigationShell: navigationShell);
      },
      branches: [
        // Aba 0: Início (Catálogo Unificado)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),

        // Aba 1: Busca
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),

        // Aba 2: Downloads
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/downloads',
              builder: (context, state) => const DownloadsScreen(),
            ),
          ],
        ),

        // Aba 3: Perfil / Ajustes / Sobre
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Gerenciar Extensões / Repositórios (acessível pelo Perfil)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/extensions',
      builder: (context, state) => const ExtensionsScreen(),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/section',
      builder: (context, state) => CatalogSectionScreen(
        sectionName: state.uri.queryParameters['name'] ?? 'Catálogo',
      ),
    ),

    // Console de Logs em Tempo Real
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/logs',
      builder: (context, state) => const LogViewerScreen(),
    ),

    // Detalhes do Título (Fullscreen Stack)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/details/:contentId/:pluginId',
      builder: (context, state) {
        final contentId = state.pathParameters['contentId'] ?? '';
        final pluginId = state.pathParameters['pluginId'] ?? '';
        final title = state.uri.queryParameters['title'];
        final poster = state.uri.queryParameters['poster'];
        final overview = state.uri.queryParameters['overview'];
        final type = ContentType.fromString(
          state.uri.queryParameters['type'] ?? 'movie',
        );
        final initialDetail = title == null
            ? null
            : ContentDetail(
                id: contentId,
                title: title,
                posterUrl: poster ?? '',
                overview: overview,
                type: type,
                pluginId: pluginId,
              );
        return DetailsScreen(
          contentId: contentId,
          pluginId: pluginId,
          initialDetail: initialDetail,
        );
      },
    ),

    // Player de Vídeo (Fullscreen Stack)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/player/:contentId/:pluginId',
      builder: (context, state) {
        final contentId = state.pathParameters['contentId'] ?? '';
        final pluginId = state.pathParameters['pluginId'] ?? '';
        final title = state.uri.queryParameters['title'] ?? 'Reproduzindo';
        final season = int.tryParse(state.uri.queryParameters['season'] ?? '');
        final episode = int.tryParse(
          state.uri.queryParameters['episode'] ?? '',
        );
        final initialSourceIndex = int.tryParse(
          state.uri.queryParameters['serverIndex'] ?? '',
        ) ?? 0;
        return PlayerScreen(
          contentId: contentId,
          pluginId: pluginId,
          title: title,
          season: season,
          episode: episode,
          initialSourceIndex: initialSourceIndex,
        );
      },
    ),
  ],
);
