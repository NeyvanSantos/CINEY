/// Destinos fechados: o servidor nunca fornece uma rota ou URL executável.
String? notificationRoute(Map<String, dynamic> data) {
  switch (data['kind']) {
    case 'digest':
      return '/home';
    case 'app_update':
      return '/profile?checkUpdate=1';
    case 'test':
      return '/notification-settings';
    case 'episode':
      const plugins = {
        'series': 'com.supercine',
        'anime': 'com.animescloud',
        'dorama': 'com.doramas',
      };
      final category = data['category'];
      final id = '${data['tmdb_id'] ?? ''}';
      final plugin = plugins[category];
      if (plugin == null || !RegExp(r'^[1-9]\d{0,11}$').hasMatch(id)) {
        return null;
      }
      return Uri(
        path: '/details/tmdb_${id}_$category/$plugin',
        queryParameters: {'type': '$category'},
      ).toString();
    default:
      return null;
  }
}

const notificationPreferenceLabels = {
  'enabled': 'Receber notificações',
  'movies': 'Filmes',
  'series': 'Séries',
  'anime': 'Animes',
  'dorama': 'Doramas',
  'episodes': 'Episódios dos meus favoritos',
  'app_updates': 'Novidades e atualizações do CiNey',
};

Map<String, bool> notificationPreferences(Map<String, dynamic>? row) => {
  for (final key in notificationPreferenceLabels.keys)
    key: row?[key] is bool ? row![key] as bool : true,
};
