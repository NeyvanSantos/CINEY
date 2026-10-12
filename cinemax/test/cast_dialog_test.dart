import 'package:cinemax/core/services/app_logger.dart';
import 'package:cinemax/features/cast/presentation/cast_dialog.dart';
import 'package:cinemax/plugin_engine/models/stream_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

// O dialogo inicializa o sniffer mesmo sem iniciar uma transmissao.
class _WebPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _Controller(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _Navigation(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _View(params);
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setUserAgent(String? userAgent) async {}
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
}

class _Navigation extends PlatformNavigationDelegate {
  _Navigation(super.params) : super.implementation();

  @override
  Future<void> setOnProgress(ProgressCallback callback) async {}
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {}
}

class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

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
  setUp(() => WebViewPlatform.instance = _WebPlatform());
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
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(openedPlayer, isFalse);
    await tester.ensureVisible(find.text('Assistir no celular'));
    await tester.tap(find.text('Assistir no celular'));
    await tester.pumpAndSettle();
    expect(openedPlayer, isTrue);
    expect(find.byType(CastDialog), findsNothing);
  });

  testWidgets('exibe seletor de servidor quando há múltiplas fontes', (
    tester,
  ) async {
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
    expect(find.text('Chromecast / Google TV'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('trocar servidor atualiza a selecao de transmissão', (
    tester,
  ) async {
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
    final selected = find.ancestor(
      of: find.text('SuperFlix'),
      matching: find.byType(InkWell),
    );
    expect(
      find.descendant(
        of: selected,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsNothing,
    );
    await tester.ensureVisible(find.text('SuperFlix'));
    await tester.tap(find.text('SuperFlix'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: selected,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('instruções cabem em modo paisagem com rolagem', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openDialog(tester, sources: _testSources);
    await tester.ensureVisible(find.text('Chromecast / Google TV'));
    expect(tester.takeException(), isNull);
  });
}
