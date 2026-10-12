import 'package:cinemax/core/services/app_logger.dart';
import 'package:cinemax/features/cast/presentation/cast_dialog.dart';
import 'package:cinemax/plugin_engine/models/stream_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const castChannel = MethodChannel('com.cinemax.cinemax/cast');

const _testSources = [
  StreamSource(
    url: 'https://myembed.biz/filme/123',
    quality: 'Conforme o fornecedor',
    server: 'EmbedMovies',
    isEmbed: true,
    isDirect: false,
    priority: 1,
  ),
  StreamSource(
    url: 'https://superflixapi.monster/filme/123',
    quality: '1080p Full HD',
    server: 'SuperFlix',
    isEmbed: true,
    isDirect: false,
    priority: 2,
  ),
];

Future<void> openDialog(
  WidgetTester tester, {
  VoidCallback? onOpenPlayer,
  List<StreamSource> sources = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => CastDialog.show(
              context,
              title: 'Filme de teste',
              sources: sources,
              onOpenPlayer: onOpenPlayer,
            ),
            child: const Text('Transmitir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Transmitir'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(AppLogger.clear);

  testWidgets('não abre sem uma fonte de mídia e botão aparece desabilitado', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      castChannel,
      (call) async {
        calls.add(call.method);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        castChannel,
        null,
      ),
    );
    var openedPlayer = false;
    await openDialog(tester, onOpenPlayer: () => openedPlayer = true);
    expect(calls, isEmpty);
    // Sem fontes: botão mostra "Nenhuma fonte disponível" e está desabilitado
    expect(find.text('Nenhuma fonte disponível'), findsOneWidget);
    expect(openedPlayer, isFalse);
    await tester.ensureVisible(find.text('Abrir filme'));
    await tester.tap(find.text('Abrir filme'));
    await tester.pumpAndSettle();
    expect(openedPlayer, isTrue);
    expect(find.byType(CastDialog), findsNothing);
  });

  testWidgets('exibe seletor de servidor quando há múltiplas fontes', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      castChannel,
      (call) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        castChannel,
        null,
      ),
    );
    await openDialog(tester, sources: _testSources);
    // Deve mostrar o seletor com ambos os servidores
    expect(find.text('Escolha o Servidor'), findsOneWidget);
    expect(find.text('EmbedMovies'), findsOneWidget);
    expect(find.text('SuperFlix'), findsOneWidget);
    // Botão principal mostra o servidor selecionado (primeiro por padrão)
    expect(find.text('Transmitir via EmbedMovies'), findsOneWidget);
  });

  testWidgets('trocar servidor altera o botão de transmissão', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      castChannel,
      (call) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        castChannel,
        null,
      ),
    );
    await openDialog(tester, sources: _testSources);
    // Selecionar SuperFlix
    await tester.ensureVisible(find.text('SuperFlix'));
    await tester.tap(find.text('SuperFlix'));
    await tester.pumpAndSettle();
    // Botão agora mostra "Transmitir via SuperFlix"
    expect(find.text('Transmitir via SuperFlix'), findsOneWidget);
  });

  testWidgets('instruções cabem em modo paisagem com rolagem', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openDialog(tester, sources: _testSources);
    await tester.ensureVisible(find.text('Transmitir via EmbedMovies'));
    expect(tester.takeException(), isNull);
  });
}
