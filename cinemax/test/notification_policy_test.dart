import 'package:flutter_test/flutter_test.dart';
import 'package:cinemax/mobile/notification_policy.dart';

void main() {
  test('push routes allow only known destinations and TMDB details', () {
    expect(notificationRoute({'kind': 'digest'}), '/home');
    expect(notificationRoute({'kind': 'app_update'}), '/profile?checkUpdate=1');
    expect(notificationRoute({'kind': 'test'}), '/notification-settings');
    expect(
      notificationRoute({
        'kind': 'episode',
        'category': 'anime',
        'tmdb_id': '42',
        'plugin_id': 'untrusted',
        'url': 'https://evil.example',
      }),
      '/details/tmdb_42_anime/com.animescloud?type=anime',
    );
    for (final id in [
      '../profile',
      '0',
      '-1',
      'https://evil.example',
      '1?admin=1',
    ]) {
      expect(
        notificationRoute({
          'kind': 'episode',
          'category': 'series',
          'tmdb_id': id,
        }),
        isNull,
      );
    }
    expect(
      notificationRoute({
        'kind': 'episode',
        'category': 'unknown',
        'tmdb_id': '42',
      }),
      isNull,
    );
    expect(
      notificationRoute({'kind': 'custom', 'route': '/player/42/plugin'}),
      isNull,
    );
  });
  test('preferences use explicit boolean values only', () {
    expect(
      notificationPreferences(null).values.every((value) => value),
      isTrue,
    );
    final prefs = notificationPreferences({
      'movies': false,
      'enabled': true,
      'anime': 'false',
      'user_id': 'ignored',
    });
    expect(prefs['movies'], isFalse);
    expect(prefs['anime'], isTrue);
    expect(prefs.containsKey('user_id'), isFalse);
  });
}
