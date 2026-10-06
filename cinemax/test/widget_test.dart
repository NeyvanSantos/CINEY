import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemax/core/services/app_updater.dart';
import 'package:cinemax/core/widgets/glass_card.dart';
import 'package:cinemax/core/widgets/gradient_poster.dart';
import 'package:cinemax/core/widgets/update_dialog.dart';

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
}
