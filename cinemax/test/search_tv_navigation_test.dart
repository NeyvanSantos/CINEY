import 'dart:async';
import 'package:ciney_core/core/config/app_environment.dart';
import 'package:ciney_core/core/widgets/gradient_poster.dart';
import 'package:ciney_core/features/search/presentation/search_screen.dart';
import 'package:ciney_core/plugin_engine/manager/plugin_manager.dart';
import 'package:ciney_core/plugin_engine/models/content_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Catalog extends PluginManager {
  Completer<List<ContentItem>>? pending;
  static final items = List.generate(
    12,
    (index) => ContentItem(
      id: 'film_$index',
      title: 'Filme $index',
      posterUrl: '',
      year: '2023',
      type: ContentType.movie,
      pluginId: 'test',
    ),
  );
  @override
  Future<List<ContentItem>> searchAll(String query) async =>
      pending == null ? items : pending!.future;
}

void main() {
  setUp(() => AppEnvironment.isTv = true);
  tearDown(() => AppEnvironment.isTv = false);
  Future<void> open(WidgetTester tester, _Catalog catalog) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Row(
            children: [
              SizedBox(width: 88),
              Expanded(child: SearchScreen()),
            ],
          ),
        ),
        GoRoute(
          path: '/details/:id/:plugin',
          builder: (_, state) =>
              Scaffold(body: Text('Detalhes ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pluginManagerProvider.overrideWith((ref) => catalog)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Velozes');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  bool posterFocused(WidgetTester tester, int index) {
    final ink = find
        .descendant(
          of: find.byType(GradientPoster).at(index),
          matching: find.byType(InkWell),
        )
        .first;
    return Focus.of(tester.element(ink)).hasFocus;
  }

  testWidgets('baixo vai direto ao filme e cima retorna à pesquisa', (
    tester,
  ) async {
    await open(tester, _Catalog());
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(posterFocused(tester, 0), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(posterFocused(tester, 1), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Detalhes film_1'), findsOneWidget);
  });
  testWidgets('cartaz preenche célula e primeira linha cabe na TV', (
    tester,
  ) async {
    await open(tester, _Catalog());
    await tester.pumpAndSettle();
    final poster = find.byType(GradientPoster).first;
    final image = find.descendant(
      of: poster,
      matching: find.byType(CachedNetworkImage),
    );
    expect(
      tester.getSize(image).width,
      closeTo(tester.getSize(poster).width, 1),
    );
    expect(tester.getRect(poster).bottom, lessThanOrEqualTo(540));
    final widget = tester.widget<CachedNetworkImage>(image);
    expect(
      widget.memCacheWidth,
      closeTo(tester.getSize(image).width * tester.view.devicePixelRatio, 1),
    );
  });
  testWidgets(
    'baixo durante consulta transfere foco quando chegam resultados',
    (tester) async {
      final catalog = _Catalog()..pending = Completer<List<ContentItem>>();
      await open(tester, catalog);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      catalog.pending!.complete(_Catalog.items);
      await tester.pumpAndSettle();
      expect(posterFocused(tester, 0), isTrue);
    },
  );
}
