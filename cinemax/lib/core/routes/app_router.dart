import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/account_screen.dart';
import '../../features/auth/presentation/tv_pairing_scanner_screen.dart';
import '../../features/auth/presentation/tv_pairing_screen.dart';
import '../../features/auth/services/account_repository.dart';
import '../../features/favorites/presentation/favorites_screen.dart';

final appRouterProvider = Provider.autoDispose.family<GoRouter, bool>((
  ref,
  isTv,
) {
  final router = createAppRouter(
    accounts: ref.watch(accountRepositoryProvider),
    isTv: isTv,
  );
  ref.listen(accountUserProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createAppRouter({
  required AccountRepository accounts,
  bool isTv = false,
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  var hadSession = accounts.currentUser != null;
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      if (accounts.currentUser != null) {
        hadSession = true;
        // Confirmation and password recovery finish on the authentication screen.
        return null;
      }
      final path = state.uri.path;
      if (path == '/splash' ||
          path == '/auth' ||
          (isTv && path == '/tv-pair')) {
        return null;
      }
      return hadSession ? '/auth?mode=login' : '/auth';
    },
    routes: [
      GoRoute(
        path: '/auth',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AuthScreen(
          requireAccount: true,
          startWithSignup: state.uri.queryParameters['mode'] != 'login',
          isTv: isTv,
        ),
      ),
      GoRoute(
        path: '/account',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/favorites',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/tv-pair',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TvPairingScreen(isEntry: true),
      ),
      GoRoute(
        path: '/tv-pair-scan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TvPairingScannerScreen(),
      ),
      // Splash Screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Onboarding / Setup Inicial (Idioma e Fontes)
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Stateful Navigation Shell (Bottom Navigation Bar)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavScreen(navigationShell: navigationShell, isTv: isTv);
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
        parentNavigatorKey: rootNavigatorKey,
        path: '/extensions',
        builder: (context, state) => const ExtensionsScreen(),
      ),

      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/section',
        builder: (context, state) => CatalogSectionScreen(
          sectionName: state.uri.queryParameters['name'] ?? 'Catálogo',
          initialItems: state.extra is List<ContentItem>
              ? state.extra as List<ContentItem>
              : null,
        ),
      ),

      // Console de Logs em Tempo Real
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/logs',
        builder: (context, state) => const LogViewerScreen(),
      ),

      // Detalhes do Título (Fullscreen Stack)
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
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
            isTv: isTv,
          );
        },
      ),

      // Player de Vídeo (Fullscreen Stack)
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/player/:contentId/:pluginId',
        builder: (context, state) {
          final contentId = state.pathParameters['contentId'] ?? '';
          final pluginId = state.pathParameters['pluginId'] ?? '';
          final title = state.uri.queryParameters['title'] ?? 'Reproduzindo';
          final contentTitle = state.uri.queryParameters['contentTitle'];
          final posterUrl = state.uri.queryParameters['poster'] ?? '';
          final mediaType = state.uri.queryParameters['type'] ?? 'movie';
          final resumePositionMs =
              int.tryParse(
                state.uri.queryParameters['resumePositionMs'] ?? '',
              ) ??
              0;
          final season = int.tryParse(
            state.uri.queryParameters['season'] ?? '',
          );
          final episode = int.tryParse(
            state.uri.queryParameters['episode'] ?? '',
          );
          final initialSourceIndex = int.tryParse(
            state.uri.queryParameters['serverIndex'] ?? '',
          );
          final initialServer = state.uri.queryParameters['server'];
          return PlayerScreen(
            contentId: contentId,
            pluginId: pluginId,
            title: title,
            contentTitle: contentTitle,
            posterUrl: posterUrl,
            mediaType: mediaType,
            season: season,
            episode: episode,
            resumePositionMs: resumePositionMs,
            initialSourceIndex: initialSourceIndex,
            initialServer: initialServer,
            isTv: isTv,
          );
        },
      ),
    ],
  );
}
