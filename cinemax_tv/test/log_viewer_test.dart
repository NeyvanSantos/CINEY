import 'package:cinemax/core/services/app_logger.dart';
import 'package:cinemax/features/profile/presentation/log_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppLogger.clear();
  });
  tearDown(AppLogger.clear);

  testWidgets('filtra, limpa pesquisa, copia e limpa logs em tempo real', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    AppLogger.info('Busca concluída', tag: 'SEARCH');
    AppLogger.error('Servidor falhou', tag: 'PLAYER');
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LogViewerScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('2 de 2 entradas'), findsOneWidget);
    await tester.tap(find.text('Erro'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('1 de 2 entradas'), findsOneWidget);
    await tester.tap(find.text('Copiar Tudo'));
    await tester.pump();
    expect(copiedText, contains('[PLAYER] Servidor falhou'));
    expect(copiedText, isNot(contains('Busca concluída')));
    await tester.tap(find.text('Limpar filtros'));
    await tester.enterText(find.byType(TextField), 'SEARCH');
    await tester.pump();
    expect(find.text('1 de 2 entradas'), findsOneWidget);
    await tester.tap(find.text('Limpar filtros'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text('2 de 2 entradas'), findsOneWidget);
    AppLogger.success('Vídeo pronto', tag: 'PLAYER');
    await tester.pump();
    await tester.pump();
    expect(find.text('3 de 3 entradas'), findsOneWidget);
    await tester.tap(find.byTooltip('Limpar todos os logs'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Nenhum log registrado'), findsOneWidget);
    expect(AppLogger.entries, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
