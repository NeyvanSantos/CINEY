import 'package:integration_test/integration_test.dart';
import 'package:cinemax_tv/tv_services.dart';
import '../../packages/ciney_core/test/tv_hls_playback_scenarios.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureTvServices();
  registerTvHlsTests();
}
