import 'package:cinemax/features/player/services/embed_playback_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
