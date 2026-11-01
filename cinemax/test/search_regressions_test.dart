import 'dart:async';
import 'package:ciney_core/features/search/presentation/search_screen.dart';
import 'package:ciney_core/plugin_engine/manager/plugin_manager.dart';
import 'package:ciney_core/plugin_engine/models/content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Search extends PluginManager {
  final requests = <String, Completer<List<ContentItem>>>{};
  @override
  Future<List<ContentItem>> searchAll(String query) =>
      (requests[query] = Completer<List<ContentItem>>()).future;
}

void main() {
  testWidgets('resposta antiga não encerra carregamento da nova consulta', (
    tester,
  ) async {
    final search = _Search();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pluginManagerProvider.overrideWith((ref) => search)],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'antiga');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), 'nova');
    search.requests['antiga']!.complete([]);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    search.requests['nova']!.completeError(StateError('offline'));
    await tester.pump();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    search.requests['nova']!.complete([]);
    await tester.pump();
    expect(find.text('Tentar novamente'), findsNothing);
  });
}
