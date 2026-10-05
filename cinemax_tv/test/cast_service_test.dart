import 'package:cinemax/features/cast/models/cast_device.dart';
import 'package:cinemax/features/cast/services/universal_cast_service.dart';
import 'package:cinemax/features/cast/services/web_cast_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Universal Cast Service Tests', () {
    test('WebCastServer inicializa e gera URL local válida', () async {
      final server = WebCastServer.instance;
      final started = await server.start(port: 8099);
      expect(started, true);
      expect(server.isRunning, true);
      expect(server.tvUrl, contains(':8099'));

      server.updateMedia(
        title: 'Duna 2',
        mediaUrl: 'https://myembed.biz/filme/693134',
      );

      await server.stop();
      expect(server.isRunning, false);
    });

    test('UniversalCastService conecta a dispositivo WebCast e gerencia estado', () async {
      final castService = UniversalCastService();
      const device = CastDevice(
        id: 'web_cast',
        name: 'Smart TV Web',
        type: CastDeviceType.webCast,
      );

      final success = await castService.connectAndCast(
        device: device,
        title: 'Filme Teste',
        mediaUrl: 'https://myembed.biz/filme/550',
      );

      expect(success, true);
      expect(castService.state?.state, CastPlaybackState.playing);
      expect(castService.state?.title, 'Filme Teste');

      castService.pause();
      expect(castService.state?.state, CastPlaybackState.paused);

      castService.play();
      expect(castService.state?.state, CastPlaybackState.playing);

      castService.disconnect();
      expect(castService.state, isNull);
    });
  });
}
