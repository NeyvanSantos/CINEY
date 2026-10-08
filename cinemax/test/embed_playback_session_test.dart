import 'package:cinemax/features/player/services/embed_playback_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'retomada pendente não confirma conclusão e consulta conserva a fração de segundo',
    () {
      var ended = 0;
      final session = EmbedPlaybackSession(
        onChanged: () {},
        onFailure: (_) {},
        onEnded: () => ended++,
      );
      session.receive(
        '{"event":"media","mediaId":"film","readyState":4,"current":1200,"duration":1200,"paused":false,"ended":true,"restoring":true}',
      );
      expect(session.restoring, isTrue);
      expect(session.completed, isFalse);
      expect(ended, 0);
      session.receive(
        '{"event":"media","mediaId":"film","readyState":4,"current":987.654,"duration":1200,"paused":true,"restoring":false,"requestId":"close"}',
      );
      expect(session.position, 987.654);
      expect(session.progressRequestId, 'close');
      expect(session.restoring, isFalse);
      session.dispose();
    },
  );
  test('fim real avança uma vez; pausa, buffering e posição próxima não avançam', () {
    var ended = 0;
    final session = EmbedPlaybackSession(
      onChanged: () {},
      onFailure: (_) {},
      onEnded: () => ended++,
    );
    session.receive(
      '{"event":"media","mediaId":"episode","readyState":4,"current":10,"duration":1200,"paused":false}',
    );
    session.receive(
      '{"event":"media","mediaId":"episode","readyState":4,"current":1199,"duration":1200,"paused":true}',
    );
    expect(ended, 0);
    session.receive(
      '{"event":"media","mediaId":"episode","readyState":1,"current":1200,"duration":1200,"paused":true,"ended":true}',
    );
    expect(ended, 0);
    for (var n = 0; n < 2; n++) {
      session.receive(
        '{"event":"media","mediaId":"episode","readyState":4,"current":1200,"duration":1200,"paused":true,"ended":true}',
      );
    }
    expect(ended, 1);
    session.dispose();
  });

  test('anúncio curto e sinal antigo não concluem a mídia selecionada', () {
    var ended = 0;
    final session = EmbedPlaybackSession(
      onChanged: () {},
      onFailure: (_) {},
      onEnded: () => ended++,
    );
    session.receive(
      '{"event":"media","mediaId":"episode","readyState":4,"current":10,"duration":1200,"paused":false}',
    );
    expect(
      session.receive(
        '{"event":"media","mediaId":"ad","readyState":4,"current":30,"duration":30,"paused":true,"ended":true}',
      ),
      isFalse,
    );
    expect(ended, 0);
    expect(session.duration, 1200);
    session.dispose();
    session.receive(
      '{"event":"media","mediaId":"episode","readyState":4,"current":1200,"duration":1200,"paused":true,"ended":true}',
    );
    expect(ended, 0);
  });

  test('mensagem de término sem reprodução anterior não avança', () {
    var ended = 0;
    final session = EmbedPlaybackSession(
      onChanged: () {},
      onFailure: (_) {},
      onEnded: () => ended++,
    );
    session.receive(
      '{"event":"media","readyState":4,"current":1200,"duration":1200,"paused":true,"ended":true}',
    );
    expect(ended, 0);
    session.dispose();
  });
  testWidgets('página aberta e mensagens inválidas não confirmam vídeo', (
    tester,
  ) async {
    final failures = <String>[];
    final session = EmbedPlaybackSession(
      onChanged: () {},
      onFailure: failures.add,
    );
    session.pageStarted();
    expect(session.receive('{broken'), isFalse);
    expect(session.receive('{"event":"loaded"}'), isFalse);
    expect(
      session.receive(
        '{"event":"media","readyState":0,"current":0,"duration":0,"paused":true}',
      ),
      isFalse,
    );
    expect(session.ready, isFalse);
    await tester.pump(const Duration(seconds: 25));
    expect(failures, hasLength(1));
    session.fail('duplicate');
    expect(failures, hasLength(1));
  });

  testWidgets('vídeo pronto cancela timeout e diferencia pausa de reprodução', (
    tester,
  ) async {
    final failures = <String>[];
    final session = EmbedPlaybackSession(
      onChanged: () {},
      onFailure: failures.add,
    );
    session.receive(
      '{"event":"media","readyState":2,"current":0,"duration":120,"paused":true}',
    );
    expect(session.ready, isTrue);
    expect(session.playing, isFalse);
    await tester.pump(const Duration(seconds: 30));
    expect(failures, isEmpty);
    session.receive(
      '{"event":"media","readyState":4,"current":12,"duration":120,"paused":false}',
    );
    expect(session.playing, isTrue);
    expect(session.position, 12);
    session.receive('{"event":"error","code":3}');
    expect(failures.single, contains('código 3'));
    session.dispose();
  });

  testWidgets(
    'iframe inacessível não interrompe um vídeo possivelmente ativo',
    (tester) async {
      final failures = <String>[];
      final session = EmbedPlaybackSession(
        onChanged: () {},
        onFailure: failures.add,
      );
      session.receive('{"event":"frame","opaque":true}');
      await tester.pump(const Duration(seconds: 25));
      expect(failures, isEmpty);
      expect(session.waitExpired, isTrue);
      expect(session.ready, isFalse);
      session.pageStarted();
      await tester.pump(const Duration(seconds: 25));
      expect(failures, hasLength(1));
    },
  );

  testWidgets('trocar ou fechar servidor cancela callbacks antigos', (
    tester,
  ) async {
    final failures = <String>[];
    var changes = 0;
    final session = EmbedPlaybackSession(
      onChanged: () => changes++,
      onFailure: failures.add,
    );
    session.dispose();
    expect(session.receive('{"event":"interaction"}'), isFalse);
    session.pageStarted();
    await tester.pump(const Duration(seconds: 30));
    expect(failures, isEmpty);
    expect(changes, 0);
  });
}
