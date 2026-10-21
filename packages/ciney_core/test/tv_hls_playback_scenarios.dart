import 'dart:convert';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:ciney_core/core/config/app_environment.dart';
import 'package:ciney_core/features/player/presentation/player_screen.dart';
import 'package:ciney_core/features/player/tv/tv_embed_player.dart';
import 'package:ciney_core/features/player/tv/tv_webview_bridge.dart';
import 'package:ciney_core/plugin_engine/manager/plugin_manager.dart';
import 'package:ciney_core/plugin_engine/models/stream_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart';

class _FixtureCatalog extends PluginManager {
  _FixtureCatalog(this.url);
  final String url;

  @override
  Future<List<StreamSource>> getStreams(
    String contentId,
    String pluginId, {
    int? season,
    int? episode,
  }) async => [
    StreamSource(
      url: url,
      server: 'HLS local',
      quality: 'Auto',
      isEmbed: true,
      isDirect: false,
    ),
  ];
}

void registerTvHlsTests() {
  const base = String.fromEnvironment(
    'TV_HLS_FIXTURE',
    defaultValue: 'http://127.0.0.1:8879',
  );
  const provider = String.fromEnvironment('TV_HLS_PROVIDER');
  testWidgets(
    'TV resolves embedded HLS and plays, pauses, seeks and releases',
    (tester) async {
      AppEnvironment.isTv = true;
      await AndroidWebViewController.enableDebugging(true);
      SharedPreferences.setMockInitialValues({});
      final source = provider.isEmpty ? '$base/provider' : provider;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginManagerProvider.overrideWith(
              (ref) => _FixtureCatalog(source),
            ),
          ],
          child: const MaterialApp(
            home: PlayerScreen(
              contentId: 'local-hls-validation',
              pluginId: 'test',
              title: 'Validação HLS na TV',
              isTv: true,
              initialSourceIndex: 0,
            ),
          ),
        ),
      );
      final discovery = Stopwatch()..start();
      var selectedWithRemote = false;
      while (find.byType(Chewie).evaluate().isEmpty &&
          discovery.elapsed <
              const Duration(
                seconds: int.fromEnvironment(
                  'TV_HLS_DISCOVERY_SECONDS',
                  defaultValue: 70,
                ),
              )) {
        await tester.pump(const Duration(milliseconds: 250));
        if (provider.isNotEmpty &&
            !selectedWithRemote &&
            find.byType(TvEmbedPlayer).evaluate().isNotEmpty &&
            find.text('Ir ao player').evaluate().isEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty) {
          selectedWithRemote = true;
          // Principal -> audio -> Principal, using the same D-pad path as TV.
          final view = tester.widget<WebViewWidget>(find.byType(WebViewWidget));
          final viewId =
              (view.platform.params.controller as AndroidWebViewController)
                  .webViewIdentifier;
          for (final code in [19, 20, 23]) {
            await TvWebViewBridge.invoke('key', viewId, keyCode: code);
            await tester.pump(const Duration(milliseconds: 300));
          }
        }
      }
      expect(
        find.byType(Chewie),
        findsOneWidget,
        reason: 'The provider must hand a playable HLS to the native player.',
      );
      expect(find.byType(TvEmbedPlayer), findsNothing);
      final controller = tester
          .widget<Chewie>(find.byType(Chewie))
          .controller
          .videoPlayerController;
      expect(controller.value.isInitialized, true);
      expect(controller.value.size.width, greaterThan(0));
      expect(
        controller.value.duration,
        greaterThan(
          provider.isEmpty
              ? const Duration(minutes: 3)
              : const Duration(hours: 2),
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      final first = await controller.position;
      expect(first, greaterThan(Duration.zero));
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
      await tester.pump(const Duration(seconds: 1));
      // First key may reveal hidden controls; a second key performs pause.
      if (controller.value.isPlaying) {
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
        await tester.pump(const Duration(seconds: 1));
      }
      expect(controller.value.isPlaying, false);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(seconds: 2));
      expect(
        await controller.position,
        greaterThan(first! + const Duration(seconds: 8)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
      await tester.pump(const Duration(seconds: 4));
      expect(controller.value.isPlaying, true);
      expect(controller.value.hasError, false);
      const holdSeconds = int.fromEnvironment('TV_HLS_HOLD_SECONDS');
      if (holdSeconds > 0) {
        final start = await controller.position;
        for (var second = 0; second < holdSeconds; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(controller.value.hasError, false);
        expect(
          await controller.position,
          greaterThan(start! + Duration(seconds: holdSeconds - 3)),
        );
      }
      if (provider.isEmpty) {
        final client = HttpClient();
        try {
          final response = await (await client.getUrl(
            Uri.parse('$base/stats'),
          )).close();
          final counts =
              jsonDecode(await response.transform(utf8.decoder).join()) as Map;
          expect(counts['playlists'], greaterThanOrEqualTo(3));
          expect(counts['segments'], greaterThan(1));
          expect(counts['keys'], greaterThan(0));
          expect(counts['rejected'], 0);
        } finally {
          client.close(force: true);
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Chewie), findsNothing);
    },
  );
}
