import 'dart:convert';
import 'package:ciney_core/features/player/tv/tv_hls_candidate.dart';
import 'package:ciney_core/features/player/tv/tv_source_policy.dart';
import 'package:ciney_core/plugin_engine/models/stream_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

void main() {
  String event(String url, {Map<String, String>? headers}) => jsonEncode({
    'event': 'hls',
    'url': url,
    'referer': 'https://provider.test/player/1',
    'headers': headers,
  });

  test('preserves extensionless master, session and provider metadata', () {
    final candidate = TvHlsCandidate.parse(
      event(
        'https://media.test/master?token=local',
        headers: {
          'Authorization': 'Bearer example',
          'Cookie': 'untrusted=1',
          'Host': 'wrong.test',
          'X-Bad': 'a\r\nInjected: b',
        },
      ),
    )!;
    final source = candidate.toSource(
      const StreamSource(
        url: 'https://provider.test/player/1',
        quality: 'Auto',
        server: 'Servidor escolhido',
        audioType: AudioType.dubbed,
        isEmbed: true,
      ),
      {'Cookie': 'session=test', 'User-Agent': 'TV WebView'},
    );
    expect(source.url, 'https://media.test/master?token=local');
    expect(source.audioType, AudioType.dubbed);
    expect(source.server, 'Servidor escolhido');
    expect(source.isEmbed, false);
    expect(TvSourcePolicy.nativeFormat(source), VideoFormat.hls);
    expect(source.headers, {
      'authorization': 'Bearer example',
      'Referer': 'https://provider.test/player/1',
      'Origin': 'https://provider.test',
      'Cookie': 'session=test',
      'User-Agent': 'TV WebView',
    });
  });

  test(
    'rejects malformed messages, local schemes and embedded credentials',
    () {
      for (final value in [
        'invalid json',
        '[]',
        '{"event":"other"}',
        event('blob:https://provider.test/123'),
        event('file:///private'),
        event('https://user:password@media.test/a.m3u8'),
        ' ' * 32769,
      ]) {
        expect(TvHlsCandidate.parse(value), isNull);
      }
    },
  );
}
