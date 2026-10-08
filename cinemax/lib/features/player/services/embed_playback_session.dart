import 'dart:async';
import 'dart:convert';

/// Tracks media signals separately from page navigation.
class EmbedPlaybackSession {
  EmbedPlaybackSession({
    required this.onChanged,
    required this.onFailure,
    this.onEnded,
  }) {
    _startDeadline();
  }

  final void Function() onChanged;
  final void Function(String) onFailure;
  final void Function()? onEnded;
  String? _mediaId;
  bool _hasPlayed = false;
  bool _ended = false;
  Timer? _deadline;
  bool _closed = false;
  bool ready = false;
  bool playing = false;
  bool opaqueFrame = false;
  bool needsInteraction = false;
  bool waitExpired = false;
  double position = 0;
  double duration = 0;
  bool restoring = false;
  bool get completed => _ended;
  String? progressRequestId;

  void _startDeadline() {
    _deadline = Timer(const Duration(seconds: 25), () {
      if (_closed || ready) return;
      if (opaqueFrame) {
        // A cross-origin frame may already be playing. Do not interrupt it
        // merely because the parent document cannot inspect its media.
        waitExpired = true;
        onChanged();
      } else {
        fail('O servidor não disponibilizou um vídeo em 25 segundos.');
      }
    });
  }

  void pageStarted() {
    if (_closed) return;
    if (ready || waitExpired) {
      _deadline?.cancel();
      _startDeadline();
    }
    ready = false;
    playing = false;
    opaqueFrame = false;
    needsInteraction = false;
    waitExpired = false;
    position = 0;
    duration = 0;
    _mediaId = null;
    _hasPlayed = false;
    _ended = false;
    restoring = false;
    progressRequestId = null;
    onChanged();
  }

  bool receive(String message) {
    if (_closed) return false;
    try {
      final data = jsonDecode(message);
      if (data is! Map<String, dynamic>) return false;
      switch (data['event']) {
        case 'frame':
          opaqueFrame = data['opaque'] == true;
        case 'interaction':
          needsInteraction = true;
        case 'media':
          final state = data['readyState'];
          final current = data['current'];
          final total = data['duration'];
          if (state is! num ||
              state < 2 ||
              current is! num ||
              !current.isFinite ||
              current < 0 ||
              total is! num ||
              !total.isFinite ||
              total < 0 ||
              data['paused'] is! bool) {
            return false;
          }
          final mediaId = data['mediaId'];
          if (mediaId != null && mediaId is! String) return false;
          if (_mediaId != null &&
              mediaId != _mediaId &&
              (mediaId == null || total < duration)) {
            return false;
          }
          if (mediaId != _mediaId) {
            _hasPlayed = false;
            _ended = false;
          }
          _mediaId = mediaId as String?;
          ready = true;
          playing = data['paused'] == false;
          position = current.toDouble();
          duration = total.toDouble();
          restoring = data['restoring'] == true;
          progressRequestId = data['requestId'] is String
              ? data['requestId'] as String
              : null;
          _hasPlayed |= playing && position > 0;
          _deadline?.cancel();
          final justEnded =
              !restoring &&
              data['ended'] == true &&
              _hasPlayed &&
              !_ended &&
              duration > 0 &&
              position >= duration - 1;
          if (justEnded) _ended = true;
          onChanged();
          if (justEnded && !_closed) onEnded?.call();
          return true;
        case 'error':
          final code = data['code'];
          if (code is! int || code < 1 || code > 4) return false;
          fail('Erro de mídia no servidor (código $code).');
          return true;
        default:
          return false;
      }
      onChanged();
      return true;
    } on FormatException {
      return false;
    }
  }

  void fail(String reason) {
    if (_closed) return;
    dispose();
    onFailure(reason);
  }

  void dispose() {
    _closed = true;
    _deadline?.cancel();
  }
}
