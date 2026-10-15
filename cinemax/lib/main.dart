import 'cinemax_app.dart';
import 'mobile/mobile_services.dart';

Future<void> main() {
  configureMobileServices();
  return runCinemaxApp();
}
