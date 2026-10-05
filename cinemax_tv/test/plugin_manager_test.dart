import 'package:flutter_test/flutter_test.dart';
import 'package:cinemax/core/services/app_logger.dart';
import 'package:cinemax/plugin_engine/manager/plugin_manager.dart';
import 'package:cinemax/plugin_engine/manager/repository_manager.dart';

void main() {
  group('Plugin Engine Tests', () {
    test('PluginManager inicializa com plugins padrão', () {
      final manager = PluginManager();
      expect(manager.state.installedPlugins.isNotEmpty, true);
      expect(manager.state.activePlugin, isNotNull);
      expect(
        manager.state.installedPlugins.any(
          (p) => p.manifest.id == 'com.megaflix',
        ),
        true,
      );
      expect(
        manager.state.installedPlugins.any(
          (p) => p.manifest.id == 'com.supercine',
        ),
        true,
      );
      expect(
        manager.state.installedPlugins.any(
          (p) => p.manifest.id == 'com.animescloud',
        ),
        true,
      );
    });

    test('PluginManager pode alternar plugin ativo e buscar seções', () async {
      final manager = PluginManager();
      manager.setActivePluginById('com.megaflix');
      expect(manager.state.activePlugin?.manifest.id, 'com.megaflix');

      final sections = await manager.getHomeSections();
      expect(sections.isNotEmpty, true);
      expect(sections.first.items.isNotEmpty, true);
    });

    test(
      'PluginManager busca de forma agregada em múltiplos plugins',
      () async {
        final manager = PluginManager();
        final results = await manager.searchAll('Duna');
        expect(results.isNotEmpty, true);
      },
    );

    test(
      'PluginManager obtém fontes para IDs TMDB sem depender da rede',
      () async {
        final manager = PluginManager();
        final streams = await manager.getStreams(
          'tmdb_693134_movie',
          'com.megaflix',
        );
        expect(streams, hasLength(2));
        expect(streams[0].server, 'EmbedMovies');
        expect(streams[0].url, 'https://myembed.biz/filme/693134');
        expect(streams[1].server, 'SuperFlix');
        expect(streams[1].url, 'https://superflixapi.monster/filme/693134');
      },
    );

    test('IDs internos usam servidores independentemente do plugin', () async {
      final manager = PluginManager();
      final streams = await manager.getStreams(
        'mf_1',
        'org.archive.publicdomain',
      );

      expect(streams, hasLength(2));
      expect(streams[0].server, 'EmbedMovies');
      expect(streams[0].url, 'https://myembed.biz/filme/693134');
      expect(streams[1].server, 'SuperFlix');
      expect(streams[1].url, 'https://superflixapi.monster/filme/693134');
    });

    test('ID desconhecido não usa fontes alternativas do plugin', () async {
      AppLogger.clear();
      final manager = PluginManager();
      final streams = await manager.getStreams(
        'ia_desconhecido',
        'org.archive.publicdomain',
      );

      expect(streams, isEmpty);
      expect(
        AppLogger.entries.any(
          (entry) => entry.tag == 'STREAM' && entry.level == LogLevel.success,
        ),
        isFalse,
      );
    });

    test('RepositoryManager inicializa repositório padrão TLN+', () {
      final repoManager = RepositoryManager();
      expect(
        repoManager.state.repositories.contains(
          'https://plugins.cinemax-stream.app/repo.json',
        ),
        true,
      );
    });
  });
}
