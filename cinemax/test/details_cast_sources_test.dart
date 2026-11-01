import 'package:ciney_core/core/platform/app_platform_services.dart';
import 'package:ciney_core/features/details/presentation/details_screen.dart';
import 'package:ciney_core/plugin_engine/manager/plugin_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemax/features/auth/services/account_repository.dart';
import 'support/fake_accounts.dart';

class _Sender implements CastingSender {
  Map<String, Object?>? request;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<void> open(Map<String, Object?> value) async {
    request = value;
  }
}

void main() {
  testWidgets('transmitir usa o MP4 próprio do Internet Archive', (
    tester,
  ) async {
    final previous = AppPlatformServices.current;
    final sender = _Sender();
    AppPlatformServices.current = AppPlatformServices(casting: sender);
    addTearDown(() => AppPlatformServices.current = previous);
    final accounts = FakeAccounts();
    addTearDown(accounts.changes.close);
    await tester.binding.setSurfaceSize(const Size(1280, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pluginManagerProvider.overrideWith((ref) => PluginManager()),
          accountRepositoryProvider.overrideWithValue(accounts),
        ],
        child: const MaterialApp(
          home: DetailsScreen(
            contentId: 'ia_sita_sings',
            pluginId: 'org.archive.publicdomain',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('details-cast-link'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(sender.request, isNotNull);
    expect(
      ((sender.request!['sources'] as List).single as Map)['url'],
      contains('archive.org'),
    );
    expect(
      find.text('Nenhum servidor disponível para transmissão.'),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
