import 'dart:async';
import 'dart:convert';

import 'package:chewie/chewie.dart';
import 'package:embed_media_observer/embed_media_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/services/app_logger.dart';
import '../../../plugin_engine/models/content_item.dart';
import '../../../plugin_engine/manager/plugin_manager.dart';
import '../../../plugin_engine/models/stream_source.dart';
import '../../../plugin_engine/runtime/stream_resolver.dart';
import '../../../plugin_engine/runtime/tmdb_service.dart';
import '../../cast/presentation/cast_dialog.dart';
import '../../cast/services/native_cast_bridge.dart';
import '../../cast/services/web_cast_server.dart';
import '../services/embed_playback_session.dart';
import '../services/embed_navigation.dart';
import '../services/embed_document.dart';
import '../services/episode_sequence.dart';
import '../services/watch_history_repository.dart';
import '../../profile/services/playback_preferences.dart';

enum VideoQuality {
  auto('Automática', 'Adapta à conexão', Icons.auto_awesome_rounded),
  fhd('1080p FHD', 'Alta definição máxima', Icons.hd_rounded),
  hd('720p HD', 'Equilibrado e rápido', Icons.high_quality_rounded),
  sd('480p SD', 'Economia de dados', Icons.sd_rounded);

  final String label;
  final String description;
  final IconData icon;
  const VideoQuality(this.label, this.description, this.icon);
}

enum AudioTrack {
  ptBrDubbed('Português (Dublado)', 'Áudio em Português Brasil', '🇧🇷'),
  ptBrSubtitled(
    'Português (Legendado)',
    'Áudio original com legenda PT-BR',
    '💬',
  ),
  original('Original', 'Áudio original sem modificações', '🌐'),
  english('Inglês (Original)', 'Áudio em Inglês', '🇺🇸');

  final String label;
  final String description;
  final String flag;
  const AudioTrack(this.label, this.description, this.flag);
}

enum SubtitleOption {
  off('Desativadas', 'Nenhuma legenda visível', Icons.subtitles_off_rounded),
  ptBr(
    'Português (BR)',
    'Legendas em Português do Brasil',
    Icons.subtitles_rounded,
  ),
  english('Inglês (EN)', 'Legendas em Inglês', Icons.subtitles_rounded),
  spanish('Espanhol (ES)', 'Legendas em Espanhol', Icons.subtitles_rounded);

  final String label;
  final String description;
  final IconData icon;
  const SubtitleOption(this.label, this.description, this.icon);
}

enum AspectRatioMode {
  standard('16:9 Padrão', 16 / 9),
  fitScreen('Ajustar à Tela', null),
  fill('Preencher Tela', null);

  final String label;
  final double? ratio;
  const AspectRatioMode(this.label, this.ratio);
}

class PlayerScreen extends ConsumerStatefulWidget {
  final String contentId;
  final String pluginId;
  final String title;
  final String? contentTitle;
  final String posterUrl;
  final String mediaType;
  final int resumePositionMs;
  final int? season;
  final int? episode;
  final bool isTv;

  const PlayerScreen({
    super.key,
    required this.contentId,
    required this.pluginId,
    required this.title,
    this.contentTitle,
    this.posterUrl = '',
    this.mediaType = 'movie',
    this.resumePositionMs = 0,
    this.season,
    this.episode,
    this.isTv = false,
    this.initialSourceIndex,
  });

  /// Null restores the saved provider; an explicit selection overrides it.
  final int? initialSourceIndex;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _tvPointerChannel = MethodChannel(
    'com.cinemax.cinemax/tv_pointer',
  );

  // Player nativo
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  // WebView (Embed Sources)
  WebViewController? _webViewController;
  EmbedPlaybackSession? _embedSession;
  final FocusNode _playerFocusNode = FocusNode(
    debugLabel: 'Native player media controls',
  );
  final FocusNode _tvPointerFocusNode = FocusNode(
    debugLabel: 'TV embed virtual pointer',
  );
  Offset? _tvPointerPosition;
  bool _tvPointerEnabled = false;
  late Future<void> _watchHistoryStarted;
  late WatchHistoryRepository _historyRepository;
  DateTime _lastWatchProgressSave = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _historyWrites = Future.value();
  late int? _season;
  late int? _episode;
  late String _title;
  late int _resumePositionMs;
  int _resumeDurationMs = 0;
  bool _resumePending = false;
  bool _closingPlayer = false;
  bool _allowExit = false;
  bool _appInBackground = false;
  Completer<void>? _progressSample;
  String? _progressRequestId;
  int _progressRequestSequence = 0;
  Future<void>? _checkpointInFlight;
  late EpisodeSequence _episodeSequence;
  Future<void>? _nextEpisodeRequest;
  EpisodeTarget? _nextEpisode;
  bool _nextEpisodeLoading = false;
  bool _nextEpisodeFailed = false;
  bool _advancingEpisode = false;
  bool _completionHandled = false;
  bool _autoPlayNextEpisode = true;
  int _streamRequest = 0;
  int? _observedWebViewId;
  final _nextEpisodeFocusNode = FocusNode(debugLabel: 'Next episode');
  final _nextEpisodeButtonKey = GlobalKey();

  bool get _hasEpisode => _season != null && _episode != null;

  bool get _isNearEpisodeEnd {
    if (_isLoading || _resumePending || _errorMessage != null) return false;
    final durationMs = _totalDuration.inMilliseconds;
    final positionMs = _currentPosition.inMilliseconds;
    if (durationMs <= 0 || positionMs <= 0 || positionMs > durationMs) {
      return false;
    }
    // No credits timestamp is provided by the sources. Estimate the closing
    // credits using the last 10% of playback, capped at two minutes.
    final windowMs = (durationMs ~/ 10).clamp(
      1,
      const Duration(minutes: 2).inMilliseconds,
    );
    return positionMs >= durationMs - windowMs;
  }

  // Lista de fontes e estado
  List<StreamSource> _sources = [];
  int _currentSourceIndex = 0;
  String? _savedServer;
  // Keep the old media's provider until its pending progress has been captured.
  String? _playbackServer;
  bool _isLoading = true;
  String? _errorMessage;

  // Estado de Reprodução Sincronizado
  bool _isPlaying = true;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isDraggingSlider = false;
  double _dragSliderValue = 0.0;
  bool _showDoubleTapForward = false;
  bool _showDoubleTapRewind = false;
  Timer? _nativeProgressTimer;

  // Controles e Customizações
  bool _controlsVisible = true;
  bool _isScreenLocked = false;
  bool _autoHideControls = true;
  bool _resumePlayback = true;
  bool _landscapeOnMobile = true;
  Timer? _hideControlsTimer;

  // Estado do Cast / Controle Remoto da TV
  bool _isCasting = false;
  String _castingDeviceName = '';
  bool _isChromecast = false;
  Timer? _castPollTimer;

  // Configurações Selecionadas
  VideoQuality _selectedQuality = VideoQuality.auto;
  AudioTrack _selectedAudio = AudioTrack.ptBrDubbed;
  SubtitleOption _selectedSubtitle = SubtitleOption.ptBr;
  AspectRatioMode _selectedAspectRatio = AspectRatioMode.standard;

  @override
  void initState() {
    super.initState();
    _season = widget.season;
    _episode = widget.episode;
    _title = widget.title;
    _resumePositionMs = widget.resumePositionMs;
    _historyRepository = ref.read(watchHistoryRepositoryProvider);
    final manager = ref.read(pluginManagerProvider.notifier);
    final catalogId = StreamResolverService.catalogIdFor(widget.contentId);
    _episodeSequence = EpisodeSequence(
      loadDetail: () => catalogId.startsWith('tmdb_')
          ? TmdbService.getDetail(catalogId, widget.pluginId)
          : manager.getDetail(catalogId, widget.pluginId),
      loadEpisodes: (season) => catalogId.startsWith('tmdb_')
          ? TmdbService.getEpisodes(
              catalogId,
              season,
              pluginId: widget.pluginId,
            )
          : manager.getEpisodes(catalogId, widget.pluginId, season),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addObserver(this);
    _watchHistoryStarted = _prepareWatchHistory();
    unawaited(_loadPlaybackPreferences());
    if (_hasEpisode) unawaited(_refreshNextEpisode());
  }

  Future<void> _loadPlaybackPreferences() async {
    PlaybackPreferences preferences;
    try {
      preferences = await ref.read(playbackPreferencesProvider.future);
    } catch (error) {
      AppLogger.warn(
        'Preferências de reprodução indisponíveis (${error.runtimeType}); usando padrões.',
        tag: 'PLAYER',
      );
      preferences = PlaybackPreferences.defaults;
    }
    if (!mounted) return;

    _autoHideControls = preferences.autoHideControls;
    _resumePlayback = preferences.resumePlayback;
    _landscapeOnMobile = preferences.landscapeOnMobile;
    _autoPlayNextEpisode = preferences.autoPlayNextEpisode;
    await _watchHistoryStarted;
    if (!mounted) return;
    SystemChrome.setPreferredOrientations(
      widget.isTv || _landscapeOnMobile
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
    _startHideControlsTimer();
    await _loadStreams();
  }

  ContentItem get _watchHistoryItem => ContentItem(
    id: widget.contentId,
    title: widget.contentTitle ?? widget.title,
    posterUrl: widget.posterUrl,
    type: ContentType.fromString(widget.mediaType),
    pluginId: widget.pluginId,
  );

  Future<void> _markWatchHistoryStarted() async {
    final repository = _historyRepository;
    await repository.markStarted(
      _watchHistoryItem,
      season: _season,
      episode: _episode,
      server: _playbackServer,
    );
    if (mounted) ref.invalidate(watchHistoryProvider);
  }

  Future<void> _prepareWatchHistory() async {
    try {
      final previous = await _historyRepository.findProgress(
        _watchHistoryItem,
        season: _season,
        episode: _episode,
      );
      if (previous != null) {
        _resumePositionMs = previous.position.inMilliseconds;
        _resumeDurationMs = previous.duration.inMilliseconds;
        _savedServer = previous.server;
      }
      await _markWatchHistoryStarted();
    } catch (error) {
      AppLogger.warn('Histórico indisponível: $error', tag: 'PLAYER');
    }
  }

  Future<void> _saveWatchProgress({
    required Duration position,
    required Duration duration,
    bool force = false,
    bool completed = false,
  }) async {
    if (_resumePending ||
        position < Duration.zero ||
        duration <= Duration.zero) {
      return;
    }
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastWatchProgressSave) < const Duration(seconds: 2)) {
      return;
    }
    _lastWatchProgressSave = now;

    final repository = _historyRepository;
    final item = _watchHistoryItem;
    final season = _season;
    final episode = _episode;
    final server = _playbackServer;
    final started = _watchHistoryStarted;
    // Capture the episode before awaiting and serialize writes across transitions.
    final write = _historyWrites.then((_) async {
      await started;
      await repository.saveProgress(
        item,
        position: position,
        duration: duration,
        completed: completed,
        season: season,
        episode: episode,
        server: server,
      );
    });
    _historyWrites = write.catchError((Object error) {
      AppLogger.warn('Falha ao salvar progresso: $error', tag: 'PLAYER');
    });
    await _historyWrites;
    if (mounted) ref.invalidate(watchHistoryProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInBackground = state != AppLifecycleState.resumed;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_checkpointPlayback(pause: true));
    }
  }

  Future<void> _checkpointPlayback({bool pause = false}) {
    final ongoing = _checkpointInFlight;
    if (ongoing != null) return ongoing;
    final request = _capturePlaybackProgress(pause: pause);
    _checkpointInFlight = request;
    return request.whenComplete(() => _checkpointInFlight = null);
  }

  Future<void> _capturePlaybackProgress({bool pause = false}) async {
    try {
      final native = _videoPlayerController;
      if (native?.value.isInitialized == true) {
        if (pause) await native!.pause().timeout(const Duration(seconds: 1));
        final position =
            await native!.position.timeout(const Duration(seconds: 1)) ??
            native.value.position;
        if (_videoPlayerController != native) return;
        native.value = native.value.copyWith(position: position);
        await _saveWatchProgress(
          position: position,
          duration: native.value.duration,
          completed: native.value.isCompleted,
          force: true,
        );
      } else {
        final controller = _webViewController;
        final session = _embedSession;
        if (controller == null || session == null) return;
        final sample = Completer<void>();
        final requestId = '${++_progressRequestSequence}';
        _progressSample = sample;
        _progressRequestId = requestId;
        final command = jsonEncode({
          'event': 'ciney:progress',
          'requestId': requestId,
          'pause': pause,
        });
        await controller
            .runJavaScript(
              'window.__cineyRequestProgress && window.__cineyRequestProgress($command);',
            )
            .timeout(const Duration(seconds: 1));
        await sample.future.timeout(
          const Duration(milliseconds: 800),
          onTimeout: () {},
        );
        if (_webViewController != controller ||
            !session.ready ||
            session.restoring) {
          return;
        }
        await _saveWatchProgress(
          position: Duration(milliseconds: (session.position * 1000).round()),
          duration: Duration(milliseconds: (session.duration * 1000).round()),
          completed: session.completed,
          force: true,
        );
      }
    } catch (error) {
      AppLogger.warn(
        'Não foi possível consultar a posição atual: $error',
        tag: 'PLAYER',
      );
    } finally {
      _progressRequestId = null;
      _progressSample = null;
    }
  }

  Future<void> _exitPlayer() async {
    if (_closingPlayer) return;
    _closingPlayer = true;
    await _checkpointPlayback(pause: true);
    await _historyWrites;
    if (!mounted) return;
    setState(() => _allowExit = true);
    Navigator.of(context).pop();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (!_autoHideControls) return;
    _hideControlsTimer = Timer(Duration(seconds: widget.isTv ? 8 : 4), () {
      if (mounted && _controlsVisible && !_isLoading && !_isDraggingSlider) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) {
        _startHideControlsTimer();
      }
    });
  }

  Future<void> _refreshNextEpisode() {
    final season = _season;
    final episode = _episode;
    if (season == null || episode == null) return Future.value();
    setState(() {
      _nextEpisode = null;
      _nextEpisodeLoading = true;
      _nextEpisodeFailed = false;
    });
    final request = () async {
      try {
        final next = await _episodeSequence
            .next(season, episode)
            .timeout(const Duration(seconds: 20));
        if (!mounted || _season != season || _episode != episode) return;
        setState(() => _nextEpisode = next);
      } catch (error) {
        if (!mounted || _season != season || _episode != episode) return;
        AppLogger.warn(
          'Lista do próximo episódio indisponível: $error',
          tag: 'EPISODES',
        );
        setState(() => _nextEpisodeFailed = true);
      } finally {
        if (mounted && _season == season && _episode == episode) {
          setState(() => _nextEpisodeLoading = false);
        }
      }
    }();
    _nextEpisodeRequest = request;
    return request;
  }

  Future<void> _onPlaybackEnded() async {
    if (!_hasEpisode ||
        _completionHandled ||
        _advancingEpisode ||
        _isCasting ||
        _closingPlayer ||
        _appInBackground) {
      return;
    }
    _completionHandled = true;
    _hideControlsTimer?.cancel();
    setState(() => _controlsVisible = true);
    if (_autoPlayNextEpisode) await _advanceEpisode();
  }

  Future<void> _advanceEpisode() async {
    if (!_hasEpisode || _advancingEpisode || _isCasting || _closingPlayer) {
      return;
    }
    setState(() => _advancingEpisode = true);
    try {
      await _nextEpisodeRequest;
      if (!mounted) return;
      if (_nextEpisodeFailed) await _refreshNextEpisode();
      if (!mounted) return;
      final next = _nextEpisode;
      if (next == null) {
        if (_nextEpisodeFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível carregar o próximo episódio. Tente novamente.',
              ),
            ),
          );
        }
        return;
      }
      final native = _videoPlayerController?.value;
      final embed = _embedSession;
      final position =
          native?.position ??
          Duration(milliseconds: ((embed?.position ?? 0) * 1000).round());
      final duration =
          native?.duration ??
          Duration(milliseconds: ((embed?.duration ?? 0) * 1000).round());
      // Stop old callbacks before switching the history identity.
      final save = _saveWatchProgress(
        position: position,
        duration: duration,
        force: true,
        completed: native?.isCompleted == true || embed?.completed == true,
      );
      _disposeCurrentPlayer(saveProgress: false);
      await save;
      if (!mounted) return;
      setState(() {
        _season = next.season;
        _episode = next.number;
        _title =
            '${widget.contentTitle ?? _watchHistoryItem.title} • ${next.title}';
        _resumePositionMs = 0;
        _resumeDurationMs = 0;
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        _completionHandled = false;
        _lastWatchProgressSave = DateTime.fromMillisecondsSinceEpoch(0);
        _isLoading = true;
      });
      _watchHistoryStarted = _markWatchHistoryStarted();
      await _watchHistoryStarted;
      if (!mounted) return;
      unawaited(_refreshNextEpisode());
      await _loadStreams();
    } catch (error, stack) {
      AppLogger.error(
        'Falha ao avançar episódio: $error',
        tag: 'PLAYER',
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível iniciar o próximo episódio. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _advancingEpisode = false);
    }
  }

  Widget _buildNextEpisodeButton() {
    final next = _nextEpisode;
    final busy = _advancingEpisode || _nextEpisodeLoading;
    return Tooltip(
      message: next == null
          ? 'Recarregar episódios'
          : 'Temporada ${next.season} • Episódio ${next.number}: ${next.title}',
      child: FilledButton.icon(
        key: _nextEpisodeButtonKey,
        focusNode: _nextEpisodeFocusNode,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
        ),
        onPressed: busy || _isCasting
            ? null
            : () => unawaited(_advanceEpisode()),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _nextEpisodeFailed
                    ? Icons.refresh_rounded
                    : Icons.skip_next_rounded,
              ),
        label: Text(
          _advancingEpisode
              ? 'Abrindo episódio…'
              : _nextEpisodeLoading
              ? 'Buscando episódio…'
              : _nextEpisodeFailed
              ? 'Recarregar episódios'
              : 'Próximo episódio',
        ),
      ),
    );
  }

  Future<void> _loadStreams() async {
    final request = ++_streamRequest;
    final preferredServer = _sources.isNotEmpty
        ? _sources[_currentSourceIndex].server
        : (widget.initialSourceIndex == null ? _savedServer : null);
    AppLogger.info(
      'Abrindo "$_title" (${widget.contentId}), plugin ${widget.pluginId}.',
      tag: 'PLAYER',
    );
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentSourceIndex = 0;
    });

    try {
      final sources = await ref
          .read(pluginManagerProvider.notifier)
          .getStreams(
            widget.contentId,
            widget.pluginId,
            season: _season,
            episode: _episode,
          );

      if (!mounted || request != _streamRequest) return;
      if (sources.isEmpty) {
        AppLogger.warn(
          'Nenhum servidor disponível para ${widget.contentId}.',
          tag: 'PLAYER',
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Nenhum servidor de vídeo disponível no momento.';
          });
        }
        return;
      }

      // Ordenar fontes por prioridade (menor = melhor servidor)
      sources.sort((a, b) => a.priority.compareTo(b.priority));
      _sources = sources;
      AppLogger.info(
        '${sources.length} servidor(es) disponível(eis).',
        tag: 'PLAYER',
      );
      int startIndex =
          widget.initialSourceIndex ??
          StreamResolverService.automaticSourceIndex(sources) ??
          0;
      if (preferredServer != null) {
        final preferredIndex = sources.indexWhere(
          (source) => source.server == preferredServer,
        );
        if (preferredIndex >= 0) startIndex = preferredIndex;
      }
      if (startIndex < 0 || startIndex >= sources.length) {
        startIndex = 0;
      }
      _currentSourceIndex = startIndex;
      await _initPlayerWithIndex(startIndex);
    } catch (error, stack) {
      AppLogger.error(
        'Falha ao carregar reprodução de ${widget.contentId}: $error',
        tag: 'PLAYER',
        stackTrace: stack,
      );
      if (!mounted || request != _streamRequest) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao carregar servidores: $error';
      });
    }
  }

  Future<void> _initPlayerWithIndex(int index) async {
    if (!mounted) return;
    if (index >= _sources.length) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Nenhum servidor disponível conseguiu reproduzir o conteúdo.';
        });
      }
      return;
    }

    final source = _sources[index];
    // Preserve the current point when switching servers for the same title.
    final oldNative = _videoPlayerController?.value;
    final oldEmbed = _embedSession;
    if (_resumePlayback && !_resumePending) {
      final position =
          oldNative?.position.inMilliseconds ??
          (oldEmbed?.ready == true ? (oldEmbed!.position * 1000).round() : 0);
      if (position > 0) _resumePositionMs = position;
      final duration =
          oldNative?.duration.inMilliseconds ??
          (oldEmbed?.ready == true ? (oldEmbed!.duration * 1000).round() : 0);
      if (duration > 0) _resumeDurationMs = duration;
    }
    AppLogger.info(
      'Carregando servidor ${index + 1}/${_sources.length}: ${source.server} (${source.isEmbed ? "WebView" : "nativo"}).',
      tag: 'PLAYER',
    );
    setState(() {
      _currentSourceIndex = index;
      _isLoading = true;
      _errorMessage = null;
      _controlsVisible = true;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      _tvPointerEnabled = false;
      _tvPointerPosition = null;
    });
    _tvPointerFocusNode.unfocus();

    _disposeCurrentPlayer();
    _playbackServer = source.server;
    _resumePending = _resumePlayback && _resumePositionMs > 0;

    if (source.isEmbed) {
      await _initWebViewPlayer(source);
    } else {
      await _initNativePlayer(source, index);
    }
  }

  Future<void> _initWebViewPlayer(StreamSource source) async {
    _playerFocusNode.unfocus();
    _tvPointerFocusNode.unfocus();
    final controller = WebViewController();
    bool isCurrent() => mounted && _webViewController == controller;
    _webViewController = controller;
    if (widget.isTv) {
      setState(() {
        _tvPointerEnabled = true;
        _tvPointerPosition = null;
      });
    }
    var loggedReady = false;
    var loggedPlaying = false;
    var loggedUnobservable = false;
    final mainPage = Uri.parse(embedDocumentBaseUrl);
    late EmbedPlaybackSession session;
    session = EmbedPlaybackSession(
      onEnded: () {
        if (isCurrent()) unawaited(_onPlaybackEnded());
      },
      onChanged: () {
        if (!isCurrent()) return;
        if (session.ready && !loggedReady) {
          loggedReady = true;
          AppLogger.success(
            'Vídeo carregado em ${source.server}.',
            tag: 'PLAYER',
          );
        }
        if (session.playing && !loggedPlaying) {
          loggedPlaying = true;
          AppLogger.success(
            'Reprodução iniciada em ${source.server}.',
            tag: 'PLAYER',
          );
        }
        if (session.waitExpired && !loggedUnobservable) {
          loggedUnobservable = true;
          AppLogger.warn(
            'O fornecedor ${source.server} usa um player interno sem confirmação de reprodução. Controles do fornecedor disponíveis.',
            tag: 'PLAYER',
          );
        }
        if (widget.isTv &&
            session.playing &&
            _tvPointerEnabled &&
            !_hasEpisode) {
          _tvPointerEnabled = false;
          _tvPointerFocusNode.unfocus();
        }
        final position = Duration(
          milliseconds: (session.position * 1000).round(),
        );
        final duration = Duration(
          milliseconds: (session.duration * 1000).round(),
        );
        final wasPlaying = _isPlaying;
        if (session.ready) _resumePending = session.restoring;
        setState(() {
          _isLoading = !session.ready;
          _currentPosition = position;
          _totalDuration = duration;
          _isPlaying = session.playing;
        });
        if (session.ready) {
          unawaited(
            _saveWatchProgress(
              position: position,
              duration: duration,
              completed: session.completed,
              force: wasPlaying && !session.playing,
            ),
          );
          if (_appInBackground && session.playing) {
            unawaited(_checkpointPlayback(pause: true));
          }
        }
      },
      onFailure: (reason) {
        if (isCurrent()) _tryNextSource(reason);
      },
    );
    _embedSession = session;

    try {
      var bridge = await rootBundle.loadString(
        AppEnvironment.assetPath('assets/player/embed_bridge.js'),
      );
      final resumeHelper = await rootBundle.loadString(
        AppEnvironment.assetPath('assets/player/playback_resume.js'),
      );
      final startupHelper = await rootBundle.loadString(
        AppEnvironment.assetPath('assets/player/embed_startup.js'),
      );
      final resumeConfiguration = buildEmbedPlaybackConfiguration(
        playerUrl: source.url,
        resumePlayback: _resumePlayback,
        resumePositionMs: _resumePositionMs,
        durationMs: _resumeDurationMs,
      );
      final helpers = '$resumeConfiguration$resumeHelper\n$startupHelper';
      bridge = '$helpers\n$bridge';
      if (!isCurrent()) return;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.black);
      if (controller.platform is AndroidWebViewController) {
        await (controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }
      await controller.addJavaScriptChannel(
        'PlayerBridge',
        onMessageReceived: (message) {
          if (!isCurrent()) return;
          if (session.receive(message.message) &&
              session.progressRequestId == _progressRequestId &&
              _progressRequestId != null &&
              !session.restoring) {
            final sample = _progressSample;
            if (sample != null && !sample.isCompleted) sample.complete();
          }
        },
      );
      if (controller.platform is AndroidWebViewController) {
        final webViewId =
            (controller.platform as AndroidWebViewController).webViewIdentifier;
        try {
          final script = await rootBundle.loadString(
            AppEnvironment.assetPath('assets/player/embed_media_observer.js'),
          );
          if (!isCurrent()) return;
          final installed = await EmbedMediaObserver.install(
            webViewId,
            '$helpers\n$script',
          );
          if (!isCurrent()) {
            await EmbedMediaObserver.remove(webViewId);
            return;
          }
          if (installed) {
            _observedWebViewId = webViewId;
            bridge = 'window.__cineyNativeFrameObserver = true;\n$bridge';
          } else {
            AppLogger.warn(
              'WebView sem observação de frames; próximo episódio manual disponível.',
              tag: 'PLAYER',
            );
          }
        } catch (error) {
          AppLogger.warn(
            'Observador de episódios indisponível: $error',
            tag: 'PLAYER',
          );
        }
      }
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!isCurrent()) return;
            if (!allowsEmbedNavigation(source.url, url)) {
              session.fail('O servidor redirecionou para uma página externa.');
              return;
            }
            session.pageStarted();
            AppLogger.debug(
              'Estrutura do iframe iniciada para ${source.server}.',
              tag: 'WEBVIEW',
            );
          },
          onPageFinished: (url) {
            if (!isCurrent()) return;
            if (widget.isTv && url == embedDocumentBaseUrl) {
              unawaited(
                controller
                    .runJavaScript('''
                (() => {
                  const frame = document.querySelector('iframe');
                  if (!frame) return;
                  frame.focus();
                  try { frame.contentWindow.focus(); } catch (_) {}
                })();
              ''')
                    .catchError((Object error) {
                      AppLogger.debug(
                        'Não foi possível direcionar o foco ao player embed.',
                        tag: 'WEBVIEW',
                      );
                    }),
              );
            }
            AppLogger.debug(
              'Documento do iframe carregado para ${source.server}; reprodução sob controle do fornecedor.',
              tag: 'WEBVIEW',
            );
          },
          onWebResourceError: (error) {
            if (!isCurrent()) return;
            AppLogger.warn(
              'Falha WebView em ${source.server}: ${error.errorCode} - ${error.description} (página principal: ${error.isForMainFrame}).',
              tag: 'WEBVIEW',
            );
            if (error.isForMainFrame == true || error.url == source.url) {
              session.fail('Servidor indisponível (${error.errorCode}).');
            }
          },
          onHttpError: (error) {
            if (!isCurrent() ||
                (error.request?.uri != mainPage &&
                    error.request?.uri != Uri.parse(source.url))) {
              return;
            }
            session.fail(
              'Servidor retornou erro HTTP ${error.response?.statusCode}.',
            );
          },
          onNavigationRequest: (request) {
            if (!isCurrent()) return NavigationDecision.prevent;
            if (allowsEmbedNavigation(
              source.url,
              request.url,
              mainFrame: request.isMainFrame,
            )) {
              return NavigationDecision.navigate;
            }
            AppLogger.warn(
              'Redirecionamento externo bloqueado: ${Uri.tryParse(request.url)?.host}.',
              tag: 'WEBVIEW',
            );
            return NavigationDecision.prevent;
          },
        ),
      );
      if (!isCurrent()) return;
      AppLogger.info(
        'Incorporando ${source.server} via iframe: ${source.url}',
        tag: 'WEBVIEW',
      );
      await controller.loadHtmlString(
        buildEmbedDocument(source.url, bridge),
        baseUrl: embedDocumentBaseUrl,
      );
    } catch (error, stack) {
      if (!isCurrent()) return;
      AppLogger.error(
        'Falha ao configurar ${source.server}: $error',
        tag: 'WEBVIEW',
        stackTrace: stack,
      );
      session.fail('Não foi possível abrir o servidor.');
    }
  }

  // ══════════════════════════════════════════════
  // Controles exclusivos das fontes diretas no player nativo.
  // ══════════════════════════════════════════════
  void _executePlayPause() {
    if (_videoPlayerController != null) {
      if (_videoPlayerController!.value.isPlaying) {
        _videoPlayerController!.pause();
        unawaited(_checkpointPlayback(pause: true));
        setState(() => _isPlaying = false);
      } else {
        _videoPlayerController!.play();
        setState(() => _isPlaying = true);
      }
    }
    _startHideControlsTimer();
  }

  void _executeSeekRelative(int seconds) {
    if (_videoPlayerController != null) {
      final newPos =
          _videoPlayerController!.value.position + Duration(seconds: seconds);
      _videoPlayerController!.seekTo(newPos);
    }
    _startHideControlsTimer();
  }

  KeyEventResult _handleRemoteMediaKey(KeyEvent event) {
    if (!widget.isTv ||
        event is! KeyDownEvent ||
        _videoPlayerController == null) {
      return KeyEventResult.ignored;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.mediaPlayPause:
        if (!_controlsVisible) {
          setState(() => _controlsVisible = true);
        }
        _executePlayPause();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaRewind:
        if (!_controlsVisible) {
          setState(() => _controlsVisible = true);
        }
        _executeSeekRelative(-10);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaFastForward:
        if (!_controlsVisible) {
          setState(() => _controlsVisible = true);
        }
        _executeSeekRelative(10);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _executeSeekTo(Duration target) {
    if (_videoPlayerController != null) {
      _videoPlayerController!.seekTo(target);
    }
    _startHideControlsTimer();
  }

  KeyEventResult _handleTvPointerKey(KeyEvent event, Size size) {
    if (!widget.isTv ||
        !_tvPointerEnabled ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }

    final position =
        _tvPointerPosition ?? Offset(size.width / 2, size.height / 2);
    const step = 36.0;
    final nextPosition = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => Offset(position.dx, position.dy - step),
      LogicalKeyboardKey.arrowDown => Offset(position.dx, position.dy + step),
      LogicalKeyboardKey.arrowLeft => Offset(position.dx - step, position.dy),
      LogicalKeyboardKey.arrowRight => Offset(position.dx + step, position.dy),
      _ => null,
    };

    if (nextPosition != null) {
      setState(() {
        _tvPointerPosition = Offset(
          nextPosition.dx.clamp(12.0, size.width - 12.0),
          nextPosition.dy.clamp(12.0, size.height - 12.0),
        );
      });
      return KeyEventResult.handled;
    }

    final isSelectKey =
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;
    if (isSelectKey) {
      if (event is KeyDownEvent) {
        unawaited(_dispatchTvPointerTap(position, size));
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _dispatchTvPointerTap(Offset position, Size size) async {
    if (size.width <= 0 || size.height <= 0) return;
    final button = _nextEpisodeButtonKey.currentContext?.findRenderObject();
    if (button is RenderBox && button.hasSize) {
      final bounds = button.localToGlobal(Offset.zero) & button.size;
      if (bounds.contains(position)) {
        if (!_nextEpisodeLoading) unawaited(_advanceEpisode());
        return;
      }
    }
    try {
      await _tvPointerChannel.invokeMethod<bool>('tap', {
        'x': position.dx / size.width,
        'y': position.dy / size.height,
      });
    } on PlatformException catch (error) {
      AppLogger.warn(
        'Não foi possível clicar no player da TV: ${error.code}.',
        tag: 'WEBVIEW',
      );
    } on MissingPluginException {
      AppLogger.warn(
        'O controle virtual está disponível apenas na versão TV.',
        tag: 'WEBVIEW',
      );
    }
  }

  void _tryNextSource(String reason) {
    if (!mounted) return;
    AppLogger.warn(
      'Falha no servidor ${_currentSourceIndex + 1}: $reason',
      tag: 'PLAYER',
    );
    final next = _currentSourceIndex + 1;
    if (next < _sources.length) {
      final nextSource = _sources[next];
      AppLogger.info(
        'Alternando automaticamente para ${nextSource.server}.',
        tag: 'PLAYER',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$reason Fallback automático → ${nextSource.server} (${next + 1}/${_sources.length})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      _initPlayerWithIndex(next);
    } else {
      AppLogger.error(
        'Todos os ${_sources.length} servidores falharam. $reason',
        tag: 'PLAYER',
      );
      setState(() {
        _isLoading = false;
        _errorMessage =
            '$reason Todos os ${_sources.length} servidores foram testados sem sucesso.';
      });
    }
  }

  Future<void> _initNativePlayer(StreamSource source, int index) async {
    VideoPlayerController? pendingController;
    try {
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': '*/*',
        ...?source.headers,
      };

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(source.url),
        httpHeaders: headers,
      );
      pendingController = controller;

      _videoPlayerController = controller;

      await controller.initialize().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw Exception('Tempo limite ao conectar com o servidor.');
        },
      );

      if (!mounted || _videoPlayerController != controller) {
        await controller.dispose();
        return;
      }
      final resumePosition = Duration(milliseconds: _resumePositionMs);
      if (_resumePlayback &&
          resumePosition > Duration.zero &&
          resumePosition < controller.value.duration) {
        await controller.seekTo(resumePosition);
      }
      if (!mounted || _videoPlayerController != controller) return;
      _resumePending = false;
      _resumeDurationMs = controller.value.duration.inMilliseconds;
      AppLogger.success(
        'Player nativo pronto: ${source.server}.',
        tag: 'PLAYER',
      );
      String? lastPlaybackError;

      controller.addListener(() {
        if (!mounted || _videoPlayerController != controller) return;
        if (controller.value.hasError &&
            controller.value.errorDescription != lastPlaybackError) {
          lastPlaybackError = controller.value.errorDescription;
          AppLogger.error(
            'Erro durante reprodução em ${source.server}: ${controller.value.errorDescription}',
            tag: 'PLAYER',
          );
        }
        if (_nativeProgressTimer?.isActive ?? false) return;
        _nativeProgressTimer = Timer(const Duration(milliseconds: 250), () {
          if (!mounted || _videoPlayerController != controller) return;
          final value = controller.value;
          final wasPlaying = _isPlaying;
          setState(() {
            _currentPosition = value.position;
            _totalDuration = value.duration;
            _isPlaying = value.isPlaying;
          });
          unawaited(
            _saveWatchProgress(
              position: value.position,
              duration: value.duration,
              completed: value.isCompleted,
              force: value.isCompleted || (wasPlaying && !value.isPlaying),
            ),
          );
          if (value.isCompleted && !value.hasError) {
            unawaited(_onPlaybackEnded());
          }
        });
      });

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: !_appInBackground && !_closingPlayer,
        looping: false,
        showControls: false, // Usamos nossa própria UI rica
        aspectRatio: controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 16 / 9,
        allowFullScreen: true,
      );

      if (mounted) {
        setState(() {
          _chewieController = chewie;
          _isLoading = false;
        });
        if (widget.isTv) _playerFocusNode.requestFocus();
      }
    } catch (e, stack) {
      if (!mounted || _videoPlayerController != pendingController) return;
      final controller = pendingController;
      if (controller != null) {
        await controller.dispose();
      }
      if (_videoPlayerController == controller) {
        _videoPlayerController = null;
      }
      AppLogger.error(
        'Falha ao iniciar ${source.server}: $e',
        tag: 'PLAYER',
        stackTrace: stack,
      );
      if (!mounted || _currentSourceIndex != index) return;
      if (index + 1 < _sources.length) {
        AppLogger.info(
          'Tentando o próximo servidor após falha de ${source.server}.',
          tag: 'PLAYER',
        );
        await _initPlayerWithIndex(index + 1);
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Erro ao inicializar o player: $e';
          });
        }
      }
    }
  }

  void _disposeCurrentPlayer({bool saveProgress = true}) {
    final nativeController = _videoPlayerController;
    if (saveProgress && nativeController?.value.isInitialized == true) {
      unawaited(
        _saveWatchProgress(
          position: nativeController!.value.position,
          duration: nativeController.value.duration,
          completed: nativeController.value.isCompleted,
          force: true,
        ),
      );
    } else if (saveProgress && _embedSession != null) {
      unawaited(
        _saveWatchProgress(
          position: Duration(
            milliseconds: (_embedSession!.position * 1000).round(),
          ),
          duration: Duration(
            milliseconds: (_embedSession!.duration * 1000).round(),
          ),
          completed: _embedSession!.completed,
          force: true,
        ),
      );
    }
    _nativeProgressTimer?.cancel();
    final sample = _progressSample;
    if (sample != null && !sample.isCompleted) sample.complete();
    final observedId = _observedWebViewId;
    _observedWebViewId = null;
    if (observedId != null) {
      unawaited(
        EmbedMediaObserver.remove(observedId).catchError((Object error) {
          AppLogger.warn('Falha ao remover observador: $error', tag: 'PLAYER');
        }),
      );
    }
    _nativeProgressTimer = null;
    _embedSession?.dispose();
    _embedSession = null;
    _chewieController?.dispose();
    _chewieController = null;
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    _webViewController = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLogger.info('Player fechado: $_title.', tag: 'PLAYER');
    _nextEpisodeFocusNode.dispose();
    _castPollTimer?.cancel();
    _hideControlsTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(
      widget.isTv ? const [] : [DeviceOrientation.portraitUp],
    );
    _playerFocusNode.dispose();
    _tvPointerFocusNode.dispose();
    _disposeCurrentPlayer(saveProgress: !_allowExit);
    super.dispose();
  }

  // ══════════════════════════════════════════════
  // Controle Remoto e Sincronização de Cast (TV)
  // ══════════════════════════════════════════════
  Future<void> _showCastDialog() async {
    _startHideControlsTimer();
    final currentPos =
        _videoPlayerController?.value.position ?? _currentPosition;
    await CastDialog.show(
      context,
      title: _title,
      sources: _sources,
      initialSourceIndex: _currentSourceIndex,
      startPosition: currentPos,
      onCastStarted: (deviceName, isChromecast) {
        _onStartCasting(deviceName, isChromecast);
      },
    );
  }

  void _onStartCasting(String deviceName, bool isChromecast) {
    setState(() {
      _isCasting = true;
      _castingDeviceName = deviceName;
      _isChromecast = isChromecast;
      _controlsVisible = true;
    });

    // Pausa a reprodução local no celular
    _videoPlayerController?.pause();

    // Inicia a sincronização periódica de status com a TV
    _startCastSyncTimer();
  }

  Future<void> _stopCasting() async {
    _castPollTimer?.cancel();
    if (_isChromecast) {
      await NativeCastBridge.stopCasting();
    }
    setState(() {
      _isCasting = false;
      _castingDeviceName = '';
    });
    // Retoma a reprodução local no celular a partir do ponto atual
    if (_videoPlayerController != null) {
      await _videoPlayerController!.seekTo(_currentPosition);
      _videoPlayerController!.play();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _toggleCastPlayPause() async {
    if (_isChromecast) {
      if (_isPlaying) {
        await NativeCastBridge.pause();
      } else {
        await NativeCastBridge.play();
      }
    } else {
      if (_isPlaying) {
        WebCastServer.instance.pause();
      } else {
        WebCastServer.instance.play();
      }
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  Future<void> _seekCast(Duration newPosition) async {
    final clamped = newPosition < Duration.zero
        ? Duration.zero
        : (_totalDuration > Duration.zero && newPosition > _totalDuration
              ? _totalDuration
              : newPosition);

    setState(() {
      _currentPosition = clamped;
    });

    if (_isChromecast) {
      await NativeCastBridge.seekTo(clamped);
    } else {
      WebCastServer.instance.seekTo(clamped.inSeconds.toDouble());
    }
  }

  void _startCastSyncTimer() {
    _castPollTimer?.cancel();
    _castPollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || !_isCasting) {
        timer.cancel();
        return;
      }

      if (_isChromecast) {
        final status = await NativeCastBridge.getMediaStatus();
        if (status != null && mounted) {
          final isConnected = status['isConnected'] as bool? ?? false;
          if (!isConnected) {
            _stopCasting();
            return;
          }
          final isPlaying = status['isPlaying'] as bool? ?? false;
          final posMs = (status['positionMs'] as num?)?.toInt() ?? 0;
          final durMs = (status['durationMs'] as num?)?.toInt() ?? 0;

          setState(() {
            _isPlaying = isPlaying;
            if (posMs > 0) _currentPosition = Duration(milliseconds: posMs);
            if (durMs > 0) _totalDuration = Duration(milliseconds: durMs);
          });
        }
      } else {
        final serverTime = WebCastServer.instance.currentTime;
        final serverDur = WebCastServer.instance.duration;
        final serverPlaying = WebCastServer.instance.isPlaying;

        if (mounted) {
          setState(() {
            _isPlaying = serverPlaying;
            if (serverTime > 0) {
              _currentPosition = Duration(
                milliseconds: (serverTime * 1000).toInt(),
              );
            }
            if (serverDur > 0) {
              _totalDuration = Duration(
                milliseconds: (serverDur * 1000).toInt(),
              );
            }
          });
        }
      }
    });
  }

  Widget _buildCastRemoteOverlay() {
    final progress = _totalDuration.inMilliseconds > 0
        ? (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds)
              .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      color: const Color(0xFF070B14),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              // ── Barra Superior do Remoto ──
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      _stopCasting();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.cast_connected_rounded,
                              color: AppColors.primary,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Transmitindo em $_castingDeviceName',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _stopCasting,
                    icon: const Icon(Icons.phone_android_rounded, size: 16),
                    label: const Text('Assistir no Celular'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // ── Ícone Central Pulsante da TV ──
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _isChromecast ? Icons.tv_rounded : Icons.language_rounded,
                    color: AppColors.primary,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isPlaying ? 'Reproduzindo na TV' : 'Pausado na TV',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Controlando reprodução remota em $_castingDeviceName',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),

              const Spacer(),

              // ── Controles de Mídia Principais ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 40,
                    icon: const Icon(
                      Icons.replay_10_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => _seekCast(
                      _currentPosition - const Duration(seconds: 10),
                    ),
                  ),
                  const SizedBox(width: 28),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: IconButton(
                      iconSize: 34,
                      icon: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _toggleCastPlayPause,
                    ),
                  ),
                  const SizedBox(width: 28),
                  IconButton(
                    iconSize: 40,
                    icon: const Icon(
                      Icons.forward_10_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => _seekCast(
                      _currentPosition + const Duration(seconds: 10),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Barra de Progresso com Tempo ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                        thumbColor: AppColors.primary,
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: (val) {
                          if (_totalDuration.inMilliseconds > 0) {
                            final seekTarget = Duration(
                              milliseconds:
                                  (val * _totalDuration.inMilliseconds).toInt(),
                            );
                            _seekCast(seekTarget);
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_currentPosition),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatDuration(_totalDuration),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final subtitleText = _hasEpisode
        ? 'Temporada $_season • Episódio $_episode'
        : 'Filme Completo em HD';

    return PopScope(
      canPop: _allowExit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_exitPlayer());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _playerFocusNode,
          canRequestFocus: _videoPlayerController != null,
          skipTraversal: _videoPlayerController == null,
          onKeyEvent: (node, event) {
            if (!node.hasFocus) return KeyEventResult.ignored;
            return _handleRemoteMediaKey(event);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _webViewController == null ? _toggleControls : null,
            onDoubleTapDown: _webViewController != null
                ? null
                : (details) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    if (details.localPosition.dx < screenWidth / 2) {
                      // Volta 10s
                      _executeSeekRelative(-10);
                      setState(() => _showDoubleTapRewind = true);
                      Future.delayed(const Duration(milliseconds: 600), () {
                        if (mounted) {
                          setState(() => _showDoubleTapRewind = false);
                        }
                      });
                    } else {
                      // Avança 10s
                      _executeSeekRelative(10);
                      setState(() => _showDoubleTapForward = true);
                      Future.delayed(const Duration(milliseconds: 600), () {
                        if (mounted) {
                          setState(() => _showDoubleTapForward = false);
                        }
                      });
                    }
                  },
            child: Stack(
              children: [
                // ── Área do Player de Vídeo ──
                Center(child: _buildPlayerContent()),

                // ── Feedback Visual de Duplo Toque (+10s / -10s) ──
                if (_showDoubleTapRewind)
                  Positioned(
                    left: 60,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.replay_10_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                            Text(
                              '-10s',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (_showDoubleTapForward)
                  Positioned(
                    right: 60,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.forward_10_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                            Text(
                              '+10s',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Overlay de Controles (Fade In/Out) ──
                if (!_isScreenLocked && _webViewController == null)
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.85),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withOpacity(0.90),
                            ],
                            stops: const [0.0, 0.25, 0.70, 1.0],
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // ── Barra Superior (Top Bar) ──
                              _buildTopBar(subtitleText),

                              // ── Centro (Botão Play/Pause Grande e Navegação 10s) ──
                              _buildCenterControls(),

                              // ── Barra Inferior com Barra de Progresso e Ajustes ──
                              _buildBottomBar(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Botão de Desbloqueio da Tela ──
                if (_isScreenLocked && _webViewController == null)
                  Positioned(
                    left: 20,
                    top: 20,
                    child: SafeArea(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.lock_rounded,
                            color: AppColors.primary,
                            size: 26,
                          ),
                          tooltip: 'Desbloquear Tela',
                          onPressed: () {
                            setState(() {
                              _isScreenLocked = false;
                              _controlsVisible = true;
                            });
                            _startHideControlsTimer();
                          },
                        ),
                      ),
                    ),
                  ),

                // ── Controle Remoto de Transmissão na TV (Modo Cast Ativo) ──
                if (_isCasting)
                  Positioned.fill(child: _buildCastRemoteOverlay()),

                if (_hasEpisode &&
                    _isNearEpisodeEnd &&
                    !_isScreenLocked &&
                    !_isCasting &&
                    (_nextEpisode != null ||
                        _nextEpisodeLoading ||
                        _nextEpisodeFailed ||
                        _advancingEpisode))
                  Positioned(
                    right: 16,
                    bottom: _webViewController != null ? 76 : 116,
                    child: SafeArea(child: _buildNextEpisodeButton()),
                  ),

                if (widget.isTv &&
                    _webViewController != null &&
                    _tvPointerEnabled)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        final position =
                            _tvPointerPosition ??
                            Offset(size.width / 2, size.height / 2);
                        return Focus(
                          focusNode: _tvPointerFocusNode,
                          autofocus: true,
                          onKeyEvent: (_, event) =>
                              _handleTvPointerKey(event, size),
                          child: IgnorePointer(
                            child: Stack(
                              children: [
                                Positioned(
                                  left: position.dx - 14,
                                  top: position.dy - 14,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                    ),
                                    child: const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: Icon(
                                        Icons.near_me_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // Barra Superior com Título e Botões de Ação
  // ══════════════════════════════════════════════
  Widget _buildTopBar(String subtitleText) {
    final currentServer =
        _sources.isNotEmpty && _currentSourceIndex < _sources.length
        ? _sources[_currentSourceIndex].server
        : 'Servidor';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Botão Voltar
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => unawaited(_exitPlayer()),
            ),
          ),
          const SizedBox(width: 14),

          // Título e Episódio
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  style: AppTypography.headlineMedium.copyWith(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        currentServer,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      subtitleText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Botão Bloquear Tela
          IconButton(
            icon: const Icon(Icons.lock_open_rounded, color: Colors.white70),
            tooltip: 'Bloquear Toques na Tela',
            onPressed: () {
              setState(() {
                _isScreenLocked = true;
                _controlsVisible = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tela bloqueada. Toque no cadeado para liberar.',
                  ),
                  duration: Duration(seconds: 2),
                  backgroundColor: AppColors.surface,
                ),
              );
            },
          ),

          // Botão Transmitir para TV (Cast)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _isCasting
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(
                _isCasting ? Icons.cast_connected_rounded : Icons.cast_rounded,
                color: _isCasting ? AppColors.primary : Colors.white,
                size: 20,
              ),
              tooltip: _isCasting
                  ? 'Transmitindo em $_castingDeviceName'
                  : 'Transmitir para TV',
              onPressed: _showCastDialog,
            ),
          ),

          // Botão Trocar Servidor
          if (_sources.length > 1)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.dns_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                tooltip: 'Trocar Servidor',
                onPressed: () {
                  _startHideControlsTimer();
                  _showServerSelectorModal();
                },
              ),
            ),

          // Botão Menu de Configurações do Player
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 20,
              ),
              tooltip: 'Configurações do Player',
              onPressed: () {
                _startHideControlsTimer();
                _showSettingsModal();
              },
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // Controles Centrais (Play, Pause, -10s, +10s)
  // ══════════════════════════════════════════════
  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
          onPressed: () => _executeSeekRelative(-10),
        ),
        const SizedBox(width: 28),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: IconButton(
            iconSize: 48,
            icon: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
            ),
            onPressed: _executePlayPause,
          ),
        ),
        const SizedBox(width: 28),
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
          onPressed: () => _executeSeekRelative(10),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  // Barra Inferior com Slider e Ações Rápidas
  // ══════════════════════════════════════════════
  Widget _buildBottomBar() {
    final maxSeconds = _totalDuration.inSeconds > 0
        ? _totalDuration.inSeconds.toDouble()
        : 1.0;
    final currentSeconds = _isDraggingSlider
        ? _dragSliderValue
        : _currentPosition.inSeconds.toDouble().clamp(0.0, maxSeconds);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slider de Progresso
          if (_totalDuration.inSeconds > 0)
            Row(
              children: [
                Text(
                  _formatDuration(_currentPosition),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: Colors.white24,
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                    ),
                    child: Slider(
                      value: currentSeconds,
                      min: 0.0,
                      max: maxSeconds,
                      onChangeStart: (_) {
                        setState(() => _isDraggingSlider = true);
                      },
                      onChanged: (val) {
                        setState(() => _dragSliderValue = val);
                      },
                      onChangeEnd: (val) {
                        setState(() => _isDraggingSlider = false);
                        _executeSeekTo(Duration(seconds: val.toInt()));
                      },
                    ),
                  ),
                ),
                Text(
                  _formatDuration(_totalDuration),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Informação de Qualidade e Áudio Atual
              Row(
                children: [
                  _buildPillBadge(
                    icon: _selectedQuality.icon,
                    label: _selectedQuality.label,
                    onTap: _showQualityModal,
                  ),
                  const SizedBox(width: 8),
                  _buildPillBadge(
                    label:
                        '${_selectedAudio.flag} ${_selectedAudio.label.split(' ').first}',
                    onTap: _showAudioModal,
                  ),
                  const SizedBox(width: 8),
                  _buildPillBadge(
                    icon: _selectedSubtitle.icon,
                    label: _selectedSubtitle == SubtitleOption.off
                        ? 'Sem Legenda'
                        : 'Legenda ${_selectedSubtitle.label.split(' ').first}',
                    onTap: _showSubtitleModal,
                  ),
                ],
              ),

              // Ações do lado direito
              Row(
                children: [
                  // Recarregar / Reiniciar Stream
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white70,
                    ),
                    tooltip: 'Recarregar Player',
                    onPressed: () => _initPlayerWithIndex(_currentSourceIndex),
                  ),
                  // Proporção de Tela
                  IconButton(
                    icon: const Icon(
                      Icons.aspect_ratio_rounded,
                      color: Colors.white70,
                    ),
                    tooltip: 'Formato da Tela',
                    onPressed: _showAspectRatioModal,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillBadge({
    IconData? icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        _startHideControlsTimer();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // Conteúdo do Player (WebView / Chewie)
  // ══════════════════════════════════════════════
  Widget _buildPlayerContent() {
    if (_isLoading && _webViewController == null) {
      final currentServer =
          _sources.isNotEmpty && _currentSourceIndex < _sources.length
          ? _sources[_currentSourceIndex].server
          : 'Buscando servidor';
      final serverPos = _sources.isNotEmpty
          ? 'Servidor ${_currentSourceIndex + 1}/${_sources.length}'
          : '';

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Conectando ao $currentServer...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (serverPos.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Text(
                '$serverPos • Fallback automático ativado',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 6),
          const Text(
            'Carregando streams em alta qualidade (Dublado/Legendado)',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 54,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _initPlayerWithIndex(0),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: const Text(
                    'Tentar Novamente',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_sources.length > 1) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _showServerSelectorModal,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.dns_rounded, color: Colors.white),
                    label: const Text(
                      'Outros Servidores',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    // The provider owns playback controls for embedded sources.
    if (_webViewController != null) {
      final controller = _webViewController!;
      if (widget.isTv && controller.platform is AndroidWebViewController) {
        final params =
            AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
              PlatformWebViewWidgetCreationParams(
                controller: controller.platform,
              ),
              displayWithHybridComposition: true,
            );
        return WebViewWidget.fromPlatformCreationParams(params: params);
      }
      return WebViewWidget(controller: controller);
    }
    // ── Player Nativo (Chewie) ──
    if (_chewieController != null &&
        _videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized) {
      return AspectRatio(
        aspectRatio:
            _selectedAspectRatio.ratio ??
            (_videoPlayerController!.value.aspectRatio > 0
                ? _videoPlayerController!.value.aspectRatio
                : 16 / 9),
        child: Chewie(controller: _chewieController!),
      );
    }

    return const SizedBox.shrink();
  }

  // ══════════════════════════════════════════════
  // Modais de Configuração e Ajustes
  // ══════════════════════════════════════════════

  void _showSettingsModal() {
    _showAppModal(
      title: 'Configurações de Reprodução',
      subtitle: 'Ajuste qualidade, áudio, legendas e exibição',
      children: [
        _buildSettingsItem(
          icon: Icons.hd_rounded,
          title: 'Qualidade de Vídeo',
          subtitle: _selectedQuality.label,
          onTap: () {
            Navigator.pop(context);
            _showQualityModal();
          },
        ),
        _buildSettingsItem(
          icon: Icons.audiotrack_rounded,
          title: 'Áudio & Idioma',
          subtitle: '${_selectedAudio.flag} ${_selectedAudio.label}',
          onTap: () {
            Navigator.pop(context);
            _showAudioModal();
          },
        ),
        _buildSettingsItem(
          icon: Icons.subtitles_rounded,
          title: 'Legendas',
          subtitle: _selectedSubtitle.label,
          onTap: () {
            Navigator.pop(context);
            _showSubtitleModal();
          },
        ),
        _buildSettingsItem(
          icon: Icons.dns_rounded,
          title: 'Servidores & Fontes',
          subtitle: _sources.isNotEmpty
              ? '${_sources[_currentSourceIndex].server} • ${_sources[_currentSourceIndex].audioType.label}'
              : 'Padrão',
          onTap: () {
            Navigator.pop(context);
            _showServerSelectorModal();
          },
        ),
        _buildSettingsItem(
          icon: _isCasting ? Icons.cast_connected_rounded : Icons.cast_rounded,
          title: 'Transmitir para Smart TV',
          subtitle: _isCasting
              ? 'Conectado a $_castingDeviceName'
              : 'Espelhar com Chromecast / Navegador',
          onTap: () {
            Navigator.pop(context);
            _showCastDialog();
          },
        ),
        _buildSettingsItem(
          icon: Icons.aspect_ratio_rounded,
          title: 'Proporção da Tela',
          subtitle: _selectedAspectRatio.label,
          onTap: () {
            Navigator.pop(context);
            _showAspectRatioModal();
          },
        ),
      ],
    );
  }

  void _showQualityModal() {
    _showAppModal(
      title: 'Qualidade de Reprodução',
      subtitle: 'Escolha a resolução desejada para transmissão',
      children: VideoQuality.values.map((q) {
        final isSelected = _selectedQuality == q;
        return _buildSelectableTile(
          icon: q.icon,
          title: q.label,
          subtitle: q.description,
          isSelected: isSelected,
          onTap: () {
            setState(() => _selectedQuality = q);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Qualidade definida para: ${q.label}'),
                duration: const Duration(seconds: 2),
                backgroundColor: AppColors.surface,
              ),
            );
          },
        );
      }).toList(),
    );
  }

  void _showAudioModal() {
    _showAppModal(
      title: 'Áudio e Dublagem',
      subtitle: 'Selecione a trilha sonora e idioma de áudio',
      children: AudioTrack.values.map((a) {
        final isSelected = _selectedAudio == a;
        return _buildSelectableTile(
          customLeading: Text(a.flag, style: const TextStyle(fontSize: 22)),
          title: a.label,
          subtitle: a.description,
          isSelected: isSelected,
          onTap: () {
            setState(() => _selectedAudio = a);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Áudio definido para: ${a.label}'),
                duration: const Duration(seconds: 2),
                backgroundColor: AppColors.surface,
              ),
            );
          },
        );
      }).toList(),
    );
  }

  void _showSubtitleModal() {
    _showAppModal(
      title: 'Legendas',
      subtitle: 'Ative ou desative legendas sincronizadas',
      children: SubtitleOption.values.map((s) {
        final isSelected = _selectedSubtitle == s;
        return _buildSelectableTile(
          icon: s.icon,
          title: s.label,
          subtitle: s.description,
          isSelected: isSelected,
          onTap: () {
            setState(() => _selectedSubtitle = s);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Legendas: ${s.label}'),
                duration: const Duration(seconds: 2),
                backgroundColor: AppColors.surface,
              ),
            );
          },
        );
      }).toList(),
    );
  }

  void _showAspectRatioModal() {
    _showAppModal(
      title: 'Formato e Proporção',
      subtitle: 'Ajuste como o vídeo se adapta à tela do seu aparelho',
      children: AspectRatioMode.values.map((mode) {
        final isSelected = _selectedAspectRatio == mode;
        return _buildSelectableTile(
          icon: Icons.fit_screen_rounded,
          title: mode.label,
          subtitle: mode == AspectRatioMode.standard
              ? 'Proporção original de cinema'
              : 'Preenchimento sem bordas pretas',
          isSelected: isSelected,
          onTap: () {
            setState(() => _selectedAspectRatio = mode);
            Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }

  void _showServerSelectorModal() {
    // Determina a cor e ícone baseado no tipo de áudio do servidor
    Color badgeColorFor(AudioType type) {
      switch (type) {
        case AudioType.dubbed:
          return const Color(0xFF00C853); // Verde vibrante
        case AudioType.subtitled:
          return const Color(0xFFFF9100); // Laranja
        case AudioType.mixed:
          return const Color(0xFF448AFF); // Azul
      }
    }

    IconData iconFor(AudioType type, bool isSelected) {
      if (isSelected) return Icons.play_circle_fill_rounded;
      switch (type) {
        case AudioType.dubbed:
          return Icons.record_voice_over_rounded;
        case AudioType.subtitled:
          return Icons.subtitles_rounded;
        case AudioType.mixed:
          return Icons.language_rounded;
      }
    }

    String subtitleFor(StreamSource source) {
      switch (source.audioType) {
        case AudioType.dubbed:
          return 'Áudio Dublado PT-BR • ${source.quality}';
        case AudioType.subtitled:
          return 'Áudio Original + Legendas • ${source.quality}';
        case AudioType.mixed:
          return 'Múltiplas opções de áudio • ${source.quality}';
      }
    }

    _showAppModal(
      title: 'Servidores de Transmissão',
      subtitle: '🇧🇷 Servidores dublados são priorizados automaticamente',
      children: _sources.asMap().entries.map((entry) {
        final index = entry.key;
        final source = entry.value;
        final isSelected = _currentSourceIndex == index;
        final badgeColor = badgeColorFor(source.audioType);

        return _buildSelectableTile(
          icon: iconFor(source.audioType, isSelected),
          title: source.server,
          subtitle: subtitleFor(source),
          isSelected: isSelected,
          badge: '${source.audioType.icon} ${source.audioType.label}',
          badgeColor: badgeColor,
          onTap: () {
            Navigator.pop(context);
            _initPlayerWithIndex(index);
          },
        );
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════
  // Helpers de Componentes Visuais do Modal
  // ══════════════════════════════════════════════

  void _showAppModal({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: AppTypography.headlineMedium.copyWith(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: ListView(shrinkWrap: true, children: children),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: Colors.white38,
        size: 14,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSelectableTile({
    IconData? icon,
    Widget? customLeading,
    required String title,
    required String subtitle,
    required bool isSelected,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    final effectiveBadgeColor = badgeColor ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withOpacity(0.12)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withOpacity(0.5)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading:
            customLeading ??
            Icon(
              icon ?? Icons.check_circle_rounded,
              color: isSelected ? AppColors.primary : Colors.white70,
              size: 22,
            ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? AppColors.primary : Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: effectiveBadgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: effectiveBadgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
        ),
        trailing: isSelected
            ? const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
