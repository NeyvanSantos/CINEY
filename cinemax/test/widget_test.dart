import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:cinemax/core/services/app_updater.dart';
import 'package:cinemax/core/widgets/glass_card.dart';
import 'package:cinemax/core/widgets/focusable_surface.dart';
import 'package:cinemax/core/widgets/gradient_poster.dart';
import 'package:cinemax/core/widgets/update_dialog.dart';
import 'package:cinemax/features/main_navigation/presentation/main_nav_screen.dart';

void main() {
  testWidgets('GlassCard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GlassCard(child: Text('Cinemax Glass Card'))),
      ),
    );

    expect(find.text('Cinemax Glass Card'), findsOneWidget);
  });

  testWidgets('GlassCard pode ser selecionado pelo controle', (
    WidgetTester tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusTraversalGroup(
            child: Column(
              children: [
                TextButton(
                  autofocus: true,
                  onPressed: () {},
                  child: const Text('Antes do card'),
                ),
                GlassCard(
                  onTap: () => opened = true,
                  child: const Text('Configuração'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('Ações do diálogo de atualização aceitam controle remoto', (
    WidgetTester tester,
  ) async {
    const updateInfo = AppUpdateInfo(
      latestVersion: '1.0.12',
      currentVersion: '1.0.11',
      releaseNotes: 'Ajustes de foco para TV.',
      downloadUrl: 'https://example.com/update.apk',
      releaseName: 'CiNey TV 1.0.12',
      fileSize: 1024,
      hasUpdate: true,
      htmlUrl: 'https://example.com/release',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => UpdateDialog.show(context, updateInfo),
              child: const Text('Abrir atualização'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir atualização'));
    await tester.pumpAndSettle();
    expect(find.text('Depois'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Depois'), findsNothing);
  });

  testWidgets('GradientPoster recebe foco e abre com controle', (
    WidgetTester tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusTraversalGroup(
            child: Column(
              children: [
                TextButton(
                  autofocus: true,
                  onPressed: () {},
                  child: const Text('Ver todos'),
                ),
                GradientPoster(
                  title: 'Filme de teste',
                  posterUrl: '',
                  onTap: () => opened = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('GradientPoster limita decode ao tamanho físico do card', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GradientPoster(title: 'Poster', posterUrl: ''),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.memCacheWidth, 260);
    expect(image.memCacheHeight, 390);
  });

  testWidgets('D-pad percorre e escolhe servidores em Assistir Agora', (
    WidgetTester tester,
  ) async {
    int? selectedServer;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Column(
              children: [
                FocusableSurface(
                  autofocus: true,
                  onTap: () => selectedServer = 0,
                  child: const Text('SuperFlix'),
                ),
                FocusableSurface(
                  onTap: () => selectedServer = 1,
                  child: const Text('EmbedMovies'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selectedServer, 1);
  });

  testWidgets('controle remoto sai do conteúdo e troca destinos da TV', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/tv-home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainNavScreen(navigationShell: navigationShell, isTv: true),
          branches: [
            for (final destination in [
              'tv-home',
              'tv-search',
              'tv-downloads',
              'tv-profile',
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/$destination',
                    builder: (context, state) => Scaffold(
                      body: Center(
                        child: FilledButton(
                          onPressed: () {},
                          child: Text(destination),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'TV navigation destination 0',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'TV navigation destination 1',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('tv-search'), findsOneWidget);
  });
}
