import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemax/core/widgets/glass_card.dart';
import 'package:cinemax/core/widgets/gradient_poster.dart';

void main() {
  testWidgets('GlassCard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GlassCard(child: Text('Cinemax Glass Card'))),
      ),
    );

    expect(find.text('Cinemax Glass Card'), findsOneWidget);
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
