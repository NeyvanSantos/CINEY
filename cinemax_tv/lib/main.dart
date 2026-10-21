import 'package:ciney_core/cinemax_app.dart';
import 'tv_services.dart';

Future<void> main() {
  configureTvServices();
  return runCinemaxApp(isTv: true);
}
