import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cast_device.dart';
import 'web_cast_server.dart';

final universalCastServiceProvider =
    StateNotifierProvider<UniversalCastService, CastSession?>((ref) {
  return UniversalCastService();
});

class UniversalCastService extends StateNotifier<CastSession?> {
  UniversalCastService() : super(null);

  final _webCastServer = WebCastServer.instance;

  Future<bool> connectAndCast({
    required CastDevice device,
    required String title,
    required String mediaUrl,
    String? posterUrl,
    Map<String, String>? headers,
    bool forceProxy = false,
  }) async {
    // Inicia o servidor local se for Web Cast ou suporte auxiliar
    await _webCastServer.start();

    // Se a fonte possui headers (Referer/Origin) ou se forceProxy for true,
    // usamos o proxy local para garantir que a TV toque sem rejeição
    final effectiveMediaUrl = (forceProxy || (headers != null && headers.isNotEmpty))
        ? _webCastServer.getProxiedStreamUrl(mediaUrl, headers: headers)
        : mediaUrl;

    state = CastSession(
      device: device,
      title: title,
      mediaUrl: effectiveMediaUrl,
      posterUrl: posterUrl,
      state: CastPlaybackState.connecting,
    );

    _webCastServer.updateMedia(
      title: title,
      mediaUrl: effectiveMediaUrl,
      posterUrl: posterUrl,
      headers: headers,
    );

    if (device.type == CastDeviceType.webCast) {
      state = state?.copyWith(state: CastPlaybackState.playing);
      return true;
    }

    // Fallback: inicia sessão ativa
    state = state?.copyWith(state: CastPlaybackState.playing);
    return true;
  }

  void play() {
    _webCastServer.play();
    state = state?.copyWith(state: CastPlaybackState.playing);
  }

  void pause() {
    _webCastServer.pause();
    state = state?.copyWith(state: CastPlaybackState.paused);
  }

  void stop() {
    // Nenhuma ação DLNA/SOAP necessária
  }

  void seekTo(Duration position) {
    _webCastServer.seekTo(position.inSeconds.toDouble());
    state = state?.copyWith(position: position);
  }

  void setVolume(double volume) {
    _webCastServer.setVolume(volume);
    state = state?.copyWith(volume: volume);
  }

  void disconnect() {
    stop();
    _webCastServer.stop();
    state = null;
  }
}
