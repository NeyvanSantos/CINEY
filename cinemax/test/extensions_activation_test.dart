import 'package:ciney_core/features/extensions/presentation/extensions_screen.dart';
import 'package:ciney_core/plugin_engine/manager/plugin_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('botão instalar restaura a extensão no gerenciador', (
    tester,
  ) async {
    final manager = PluginManager();
    final removedId = manager.state.installedPlugins.first.manifest.id;
    manager.removePlugin(removedId);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pluginManagerProvider.overrideWith((ref) => manager)],
        child: const MaterialApp(home: ExtensionsScreen()),
      ),
    );
    await tester.tap(find.byTooltip('Instalar').first);
    await tester.pump();
    expect(
      manager.state.installedPlugins.where((p) => p.manifest.id == removedId),
      hasLength(1),
    );
    expect(find.byTooltip('Instalar'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
