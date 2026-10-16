import 'package:ciney_core/core/config/app_environment.dart';
import 'package:integration_test/integration_test.dart';
import '../../packages/ciney_core/test/collections_loading_test.dart'
    as regression;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final size = binding.platformDispatcher.views.first.physicalSize;
  AppEnvironment.isTv = size.width > size.height;
  binding.reportData = {'target': AppEnvironment.isTv ? 'tv' : 'phone'};
  regression.main();
}
