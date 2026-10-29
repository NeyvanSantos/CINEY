import 'package:ciney_core/cinemax_app.dart';
import 'tv_services.dart';
import 'package:flutter/widgets.dart';

Future<void> main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Leave headroom for WebView, decoder and graphics buffers on low-RAM TVs.
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = 32 * 1024 * 1024
    ..maximumSize = 120;
  configureTvServices();
  return runCinemaxApp(isTv: true);
}
