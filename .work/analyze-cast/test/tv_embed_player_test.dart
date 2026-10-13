import 'package:cinemax/features/player/tv/tv_embed_document.dart';
import 'package:cinemax/features/player/tv/tv_embed_host.dart';
import 'package:cinemax/features/player/tv/tv_webview_bridge.dart';
import 'package:cinemax/features/player/tv/tv_embed_player.dart';
import 'package:cinemax/plugin_engine/models/stream_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:cinemax/features/player/presentation/player_screen.dart';
import 'package:cinemax/features/player/services/watch_history_repository.dart';
import 'package:cinemax/plugin_engine/manager/plugin_manager.dart';
import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Catalog extends PluginManager {
  @override
  Future<List<StreamSource>> getStreams(
    String contentId,
    String pluginId, {
    int? season,
    int? episode,
  }) async => [
    const StreamSource(
      url: 'https://myembed.biz/filme/1',
      quality: 'Auto',
      server: 'EmbedMovies',
      isEmbed: true,
      isDirect: false,
    ),
  ];
}

class _WebPlatform extends WebViewPlatform {
  final controllers = <_Controller>[];
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = _Controller(params);
    controllers.add(controller);
    return controller;
  }

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
  late _Navigation navigation;
  String? html;
  String? base;
  final requests = <String>[];
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setOnPlatformPermissionRequest(
    void Function(PlatformWebViewPermissionRequest) callback,
  ) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    navigation = handler as _Navigation;
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    this.html = html;
    base = baseUrl;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    requests.add(params.uri.toString());
  }
}

class _Navigation extends PlatformNavigationDelegate {
  _Navigation(super.params) : super.implementation();
  late PageEventCallback finished;
  late NavigationRequestCallback navigate;
  late WebResourceErrorCallback error;
  late HttpResponseErrorCallback httpError;
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    navigate = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    error = callback;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {
    httpError = callback;
  }
}

class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('provider-view'));
}

class _Host extends TvEmbedHost {
  _Host(this.id);
  final int id;
  late void Function(Widget, VoidCallback) fullscreen;
  late VoidCallback hideFullscreen;
  @override
  int get viewId => id;
  @override
  Future<void> configure({
    required void Function(Widget, VoidCallback) onFullscreen,
    required VoidCallback onHideFullscreen,
  }) async {
    fullscreen = onFullscreen;
    hideFullscreen = onHideFullscreen;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _WebPlatform platform;
  final hosts = <_Host>[];
  final calls = <MethodCall>[];
  var exits = 0;
  var sources = 0;
  var next = 0;
  const source = StreamSource(
    url: 'https://myembed.biz/filme/1',
    quality: 'Auto',
    server: 'EmbedMovies',
    isEmbed: true,
  );
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvEmbedPlayer(
          createHost: () {
            final host = _Host(hosts.length + 1);
            hosts.add(host);
            return host;
          },
          source: source,
          title: 'Teste',
          onExit: () => exits++,
          onSources: () => sources++,
          onNext: () => next++,
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    hosts.clear();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TvWebViewBridge.channel, (call) async {
          calls.add(call);
          return call.method != 'release';
        });
    platform = _WebPlatform();
    WebViewPlatform.instance = platform;
    exits = sources = next = 0;
  });

  testWidgets(
    'TV route uses visible provider and preserves saved position while changing server',
    (tester) async {
      final history = WatchHistoryRepository();
      const item = ContentItem(
        id: 'tmdb_1_movie',
        title: 'Teste',
        posterUrl: '',
        type: ContentType.movie,
        pluginId: 'test',
      );
      await history.saveProgress(
        item,
        position: const Duration(minutes: 10),
        duration: const Duration(minutes: 90),
        server: 'SuperFlix',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginManagerProvider.overrideWith((ref) => _Catalog()),
            watchHistoryRepositoryProvider.overrideWithValue(history),
          ],
          child: const MaterialApp(
            home: PlayerScreen(
              contentId: 'tmdb_1_movie',
              pluginId: 'test',
              title: 'Teste',
              isTv: true,
              initialSourceIndex: 0,
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(TvEmbedPlayer), findsOneWidget);
      expect(platform.controllers.single.html, contains('<iframe'));
      final progress = (await history.load()).single;
      expect(progress.server, 'EmbedMovies');
      expect(progress.position, const Duration(minutes: 10));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('fullscreen back and disposal notify provider exactly once', (
    tester,
  ) async {
    await open(tester);
    var hides = 0;
    hosts.single.fullscreen(
      const SizedBox(key: ValueKey('fullscreen')),
      () => hides++,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('fullscreen')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const ValueKey('fullscreen')), findsNothing);
    expect(hides, 1);
    expect(exits, 0);
    await tester.pumpWidget(const SizedBox());
    expect(hides, 1);
    expect(calls.where((call) => call.method == 'release').length, 1);
  });

  testWidgets(
    'Dpad OK play pause go to the platform view without pointer clicks',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Ir ao player'));
      await tester.pump();
      for (final key in [
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.select,
        LogicalKeyboardKey.mediaPlay,
        LogicalKeyboardKey.mediaPause,
      ]) {
        await tester.sendKeyEvent(key);
      }
      expect(
        calls
            .where((call) => call.method == 'key')
            .map((call) => call.arguments['keyCode']),
        [22, 23, 126, 127],
      );
      expect(calls.where((call) => call.method == 'focus').length, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('opaque provider becomes visible without media telemetry', (
    tester,
  ) async {
    await open(tester);
    final controller = platform.controllers.single;
    expect(controller.html, contains('<iframe'));
    expect(controller.base, tvEmbedBaseUrl);
    controller.navigation.finished(tvEmbedBaseUrl);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Ir ao player'));
    await tester.pump();
    expect(find.text('Servidores'), findsNothing);
    expect(find.byKey(const ValueKey('provider-view')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pump();
    expect(find.text('Servidores'), findsOneWidget);
    await tester.tap(find.text('Servidores'));
    await tester.tap(find.text('Próximo episódio'));
    expect(sources, 1);
    expect(next, 1);
    await tester.pumpWidget(const SizedBox());
    expect(controller.requests, contains('about:blank'));
  });

  testWidgets('hung document has bounded loading and can retry', (
    tester,
  ) async {
    await open(tester);
    final old = platform.controllers.single;
    await tester.pump(const Duration(seconds: 26));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('não concluiu'), findsOneWidget);
    await tester.tap(find.text('Recarregar'));
    await tester.pump();
    expect(platform.controllers.length, 2);
    expect(old.requests, contains('about:blank'));
    old.navigation.finished(tvEmbedBaseUrl);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('back opens recovery menu before exiting', (tester) async {
    await open(tester);
    await tester.tap(find.text('Ir ao player'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Servidores'), findsOneWidget);
    expect(exits, 0);
    await tester.binding.handlePopRoute();
    expect(exits, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background unloads media and requires explicit restart', (
    tester,
  ) async {
    await open(tester);
    final controller = platform.controllers.single;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(controller.requests, contains('about:blank'));
    expect(find.byKey(const ValueKey('provider-view')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.textContaining('interrompida'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'external top navigation blocked and iframe HTTP refusal actionable',
    (tester) async {
      await open(tester);
      final nav = platform.controllers.single.navigation;
      expect(
        await nav.navigate(
          NavigationRequest(url: 'intent://external', isMainFrame: true),
        ),
        NavigationDecision.prevent,
      );
      expect(
        await nav.navigate(
          NavigationRequest(
            url: 'https://provider.test/frame',
            isMainFrame: false,
          ),
        ),
        NavigationDecision.navigate,
      );
      nav.httpError(
        HttpResponseError(
          request: WebResourceRequest(uri: Uri.parse(source.url)),
        ),
      );
      await tester.pump();
      expect(find.textContaining('recusou'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
