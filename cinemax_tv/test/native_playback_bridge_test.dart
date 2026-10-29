import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ciney_core/core/platform/app_platform_services.dart';
import 'package:cinemax_tv/tv_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'dedicated playback forwards session and first frame before returning progress',
    () async {
      const channel = MethodChannel('com.ciney/tv_native_player');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var ready = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'open');
        expect(call.arguments['headers']['Referer'], 'https://provider.test/');
        expect(call.arguments['positionMs'], 12000);
        await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('ready'),
          ),
          (_) {},
        );
        expect(ready, isTrue);
        return {'positionMs': 15000, 'durationMs': 600000, 'error': false};
      });
      configureTvServices();
      final result = await AppPlatformServices.current.tvPlayback!({
        'url': 'https://media.test/master.txt',
        'headers': {'Referer': 'https://provider.test/'},
        'positionMs': 12000,
      }, () => ready = true);
      expect(result?['positionMs'], 15000);
      messenger.setMockMethodCallHandler(channel, null);
      AppPlatformServices.current = const AppPlatformServices();
    },
  );
}
