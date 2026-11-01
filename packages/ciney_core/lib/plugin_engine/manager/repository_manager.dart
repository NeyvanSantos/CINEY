import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plugin_manifest.dart';
import 'plugin_manager.dart';

class RepositoryState {
  static const bundled = 'builtin://ciney';
  final List<String> repositories;
  final String activeRepoUrl;
  final List<PluginManifest> availablePlugins;
  final bool isLoading;
  final String? error;
  const RepositoryState({
    this.repositories = const [bundled],
    this.activeRepoUrl = bundled,
    this.availablePlugins = const [],
    this.isLoading = false,
    this.error,
  });
  RepositoryState copyWith({
    List<String>? repositories,
    String? activeRepoUrl,
    List<PluginManifest>? availablePlugins,
    bool? isLoading,
    String? error,
  }) => RepositoryState(
    repositories: repositories ?? this.repositories,
    activeRepoUrl: activeRepoUrl ?? this.activeRepoUrl,
    availablePlugins: availablePlugins ?? this.availablePlugins,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

final repositoryManagerProvider =
    StateNotifierProvider<RepositoryManager, RepositoryState>(
      (ref) => RepositoryManager(),
    );

class RepositoryManager extends StateNotifier<RepositoryState> {
  RepositoryManager({Dio? client})
    : _client =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              followRedirects: false,
            ),
          ),
      super(
        RepositoryState(
          availablePlugins: PluginManager.allAvailablePlugins
              .map((p) => p.manifest)
              .toList(),
        ),
      );
  final Dio _client;
  int _request = 0;
  CancelToken? _pending;
  void addDefaultRepository() => addRepository(RepositoryState.bundled);
  void addRepository(String url) {
    final value = url.trim();
    if (value.isEmpty) return;
    state = state.copyWith(
      repositories: {...state.repositories, value}.toList(),
    );
    fetchRepositoryPlugins(value);
  }

  void removeRepository(String url) {
    final remaining = state.repositories.where((r) => r != url).toList();
    state = state.copyWith(repositories: remaining);
    if (remaining.isNotEmpty) {
      fetchRepositoryPlugins(remaining.first);
    } else {
      _request++;
      _pending?.cancel();
      state = state.copyWith(
        activeRepoUrl: '',
        availablePlugins: [],
        isLoading: false,
      );
    }
  }

  Future<Map<String, dynamic>> _document(
    String url,
    CancelToken cancellation,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Use uma URL HTTPS sem credenciais.');
    }
    final response = await _client.get<ResponseBody>(
      url,
      cancelToken: cancellation,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
      ),
    );
    final bytes = <int>[];
    await for (final chunk in response.data!.stream.timeout(
      const Duration(seconds: 8),
    )) {
      if (bytes.length + chunk.length > 1024 * 1024) {
        throw const FormatException('Manifesto muito grande.');
      }
      bytes.addAll(chunk);
    }
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
  }

  Future<void> fetchRepositoryPlugins(String repoUrl) async {
    final request = ++_request;
    _pending?.cancel();
    final cancellation = _pending = CancelToken();
    final deadline = Timer(
      const Duration(seconds: 30),
      () => cancellation.cancel('Repository deadline'),
    );
    state = state.copyWith(
      activeRepoUrl: repoUrl,
      availablePlugins: [],
      isLoading: true,
    );
    try {
      final plugins = <PluginManifest>[];
      if (repoUrl == RepositoryState.bundled) {
        plugins.addAll(
          PluginManager.allAvailablePlugins.map((p) => p.manifest),
        );
      } else {
        final data = await _document(repoUrl, cancellation);
        final entries = data['plugins'] as List;
        if (entries.length > 64) {
          throw const FormatException('Muitas extensões.');
        }
        for (final entry in entries) {
          if (!mounted || request != _request) return;
          final item = Map<String, dynamic>.from(entry as Map);
          final manifest = PluginManifest.fromJson(
            item['manifest'] is String
                ? await _document(
                    Uri.parse(
                      repoUrl,
                    ).resolve(item['manifest'] as String).toString(),
                    cancellation,
                  )
                : item,
          );
          if (manifest.id.isEmpty ||
              manifest.name.isEmpty ||
              manifest.categories.isEmpty) {
            throw const FormatException('Manifesto incompleto.');
          }
          plugins.add(manifest);
        }
      }
      if (mounted && request == _request) {
        state = state.copyWith(availablePlugins: plugins, isLoading: false);
      }
    } catch (_) {
      if (mounted && request == _request) {
        state = state.copyWith(
          isLoading: false,
          error:
              'Não foi possível carregar o repositório. Verifique a URL HTTPS, a conexão e o formato do manifesto.',
        );
      }
    } finally {
      deadline.cancel();
      if (identical(_pending, cancellation)) _pending = null;
    }
  }

  @override
  void dispose() {
    _request++;
    _pending?.cancel();
    _client.close(force: true);
    super.dispose();
  }
}
