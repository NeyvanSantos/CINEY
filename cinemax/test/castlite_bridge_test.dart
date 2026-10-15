import 'package:cinemax/mobile/mobile_services.dart';
import 'package:castlite_engine/castlite_engine.dart';
import 'package:cinemax/features/player/services/castlite_bridge_service.dart';
import 'package:cinemax/plugin_engine/models/stream_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const direct = StreamSource(
    url: 'https://media.example/master?token=Ab%2BC&part=2',
    quality: 'Auto',
    server: 'Dublado',
    isM3U8: true,
    audioType: AudioType.dubbed,
    headers: {
      'Referer': 'https://page.example/',
      'Authorization': 'test-token',
    },
  );
  const embed = StreamSource(
    url: 'https://page.example/embed?file=movie.mp4',
    quality: 'Auto',
    server: 'Embed',
    isEmbed: true,
  );

  setUp(configureMobileServices);

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CastLiteEngine.methods, null);
  });

  test('contrato mantém fonte, headers, áudio, episódio e posição', () {
    final request = CastLiteBridgeService.buildRequest(
      source: direct,
      sources: [embed, direct],
      title: 'Série - episódio 3',
      posterUrl: '',
      contentId: 'series_1',
      season: 2,
      episode: 3,
      resumePositionMs: 142000,
    );
    final sources = request['sources'] as List;
    expect(request, containsPair('version', 1));
    expect(request, containsPair('sourceIndex', 1));
    expect(request, containsPair('season', 2));
    expect(request, containsPair('episode', 3));
    expect(request, containsPair('positionMs', 142000));
    expect(sources[1]['url'], direct.url);
    expect(sources[1]['headers'], direct.headers);
    expect(sources[1]['audioLanguage'], 'pt');
    expect(sources[0]['isDirect'], false);
    expect(sources[0]['mimeType'], isNull);
  });

  test('mantém fonte selecionada quando a lista não a contém', () {
    final request = CastLiteBridgeService.buildRequest(
      source: direct,
      sources: [embed],
      title: 'Filme',
      posterUrl: '',
      resumePositionMs: -1,
    );
    expect(request['sourceIndex'], 0);
    expect((request['sources'] as List).first['url'], direct.url);
    expect(request['positionMs'], 0);
  });

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return context;
  }

  testWidgets(
    'Android abre plugin interno com o contrato, sem URI externa',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(CastLiteEngine.methods, (call) async {
            calls.add(call);
            return call.method == 'isAvailable' ? true : null;
          });
      final context = await pumpContext(tester);
      expect(
        await CastLiteBridgeService.launchCast(
          context: context,
          source: direct,
          title: 'Filme',
          posterUrl: '',
          resumePositionMs: 9000,
        ),
        true,
      );
      expect(calls.map((e) => e.method), ['isAvailable', 'open']);
      expect(calls.last.arguments['positionMs'], 9000);
      expect(calls.last.arguments['sources'][0]['headers'], direct.headers);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'plataforma indisponível informa limite sem chamar o canal',
    (tester) async {
      final context = await pumpContext(tester);
      expect(
        await CastLiteBridgeService.launchCast(
          context: context,
          source: direct,
          title: 'Filme',
          posterUrl: '',
        ),
        false,
      );
      await tester.pump();
      expect(
        find.text(
          'A transmissão está disponível no CiNey para celular Android.',
        ),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'erro nativo permite continuar no CiNey',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(CastLiteEngine.methods, (call) async {
            if (call.method == 'isAvailable') return true;
            throw PlatformException(code: 'cast_failed');
          });
      final context = await pumpContext(tester);
      expect(
        await CastLiteBridgeService.launchCast(
          context: context,
          source: direct,
          title: 'Filme',
          posterUrl: '',
        ),
        false,
      );
      await tester.pump();
      expect(
        find.text('Não foi possível abrir a transmissão. Tente novamente.'),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  test('comando inválido é rejeitado antes de acessar o dispositivo', () async {
    await expectLater(
      CastLiteEngine.command('seek', positionMs: -10),
      throwsArgumentError,
    );
    await expectLater(CastLiteEngine.command('unknown'), throwsArgumentError);
  });
}
