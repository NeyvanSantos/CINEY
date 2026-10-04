import 'dart:async';
import 'dart:convert';

/// Tracks media signals separately from page navigation.
class EmbedPlaybackSession {
  EmbedPlaybackSession({required this.onChanged, required this.onFailure}) {
    _startDeadline();
  }

  final void Function() onChanged;
  final void Function(String) onFailure;
  Timer? _deadline;
  bool _closed = false;
  bool ready = false;
  bool playing = false;
  bool opaqueFrame = false;
  bool needsInteraction = false;
  bool waitExpired = false;
  double position = 0;
  double duration = 0;

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
          ready = true;
          playing = data['paused'] == false;
          position = current.toDouble();
          duration = total.toDouble();
          _deadline?.cancel();
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
