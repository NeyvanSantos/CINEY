import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemax/core/widgets/glass_card.dart';

void main() {
  testWidgets('GlassCard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassCard(
            child: Text('Cinemax Glass Card'),
          ),
        ),
      ),
    );

    expect(find.text('Cinemax Glass Card'), findsOneWidget);
  });
}
