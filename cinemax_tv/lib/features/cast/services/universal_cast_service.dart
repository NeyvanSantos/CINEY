import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_logger.dart';
import '../models/cast_device.dart';
import 'dlna_discovery_service.dart';
import 'web_cast_server.dart';

final universalCastServiceProvider =
    StateNotifierProvider<UniversalCastService, CastSession?>((ref) {
  return UniversalCastService();
});

class UniversalCastService extends StateNotifier<CastSession?> {
  UniversalCastService() : super(null);

  final _discoveryService = DlnaDiscoveryService.instance;
  final _webCastServer = WebCastServer.instance;
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  String? _avTransportControlUrl;

  List<CastDevice> get discoveredDevices => _discoveryService.discoveredDevices;
  Stream<List<CastDevice>> get devicesStream => _discoveryService.devicesStream;

  Future<void> startDiscovery() async {
    await _discoveryService.startDiscovery();
  }

  void stopDiscovery() {
    _discoveryService.stopDiscovery();
  }

  Future<bool> connectAndCast({
    required CastDevice device,
    required String title,
    required String mediaUrl,
    String? posterUrl,
  }) async {
    state = CastSession(
      device: device,
      title: title,
      mediaUrl: mediaUrl,
      posterUrl: posterUrl,
      state: CastPlaybackState.connecting,
    );

    // Inicia o servidor local se for Web Cast ou suporte auxiliar
    await _webCastServer.start();
    _webCastServer.updateMedia(
      title: title,
      mediaUrl: mediaUrl,
      posterUrl: posterUrl,
    );

    if (device.type == CastDeviceType.webCast) {
      state = state?.copyWith(state: CastPlaybackState.playing);
      return true;
    }

    if (device.type == CastDeviceType.roku && device.ipAddress != null) {
      return await _castToRoku(device, mediaUrl);
    }

    if (device.location != null && device.location!.isNotEmpty) {
      return await _castViaDlna(device, mediaUrl, title);
    }

    // Fallback: inicia sessão ativa
    state = state?.copyWith(state: CastPlaybackState.playing);
    return true;
  }

  Future<bool> _castToRoku(CastDevice device, String mediaUrl) async {
    try {
      final ip = device.ipAddress;
      final encodedUrl = Uri.encodeComponent(mediaUrl);
      final playUrl = 'http://$ip:8060/launch/15985?u=$encodedUrl';
      await _dio.post(playUrl);
      state = state?.copyWith(state: CastPlaybackState.playing);
      return true;
    } catch (e) {
      AppLogger.warn('Falha ao enviar para Roku: $e', tag: 'DLNA');
      state = state?.copyWith(state: CastPlaybackState.error);
      return false;
    }
  }

  /// Busca a URL de controle AVTransport a partir do XML de descrição do dispositivo DLNA.
  Future<String?> _resolveAvTransportUrl(CastDevice device) async {
    if (device.location == null || device.location!.isEmpty) return null;

    try {
      final res = await _dio.get<String>(device.location!);
      if (res.data == null) return null;
      final xml = res.data!;

      // Procura o serviceType AVTransport e extrai o controlURL associado
      final avTransportPattern = RegExp(
        r'<serviceType>\s*urn:schemas-upnp-org:service:AVTransport:1\s*</serviceType>'
        r'.*?<controlURL>\s*([^<]+)\s*</controlURL>',
        caseSensitive: false,
        dotAll: true,
      );

      final match = avTransportPattern.firstMatch(xml);
      if (match == null || match.group(1) == null) return null;

      final controlPath = match.group(1)!.trim();

      // Resolve caminho relativo contra a base do location
      final locationUri = Uri.parse(device.location!);
      if (controlPath.startsWith('http')) {
        return controlPath;
      }
      return Uri(
        scheme: locationUri.scheme,
        host: locationUri.host,
        port: locationUri.port,
        path: controlPath,
      ).toString();
    } catch (e) {
      AppLogger.warn('Falha ao resolver AVTransport URL: $e', tag: 'DLNA');
      return null;
    }
  }

  /// Envia uma ação SOAP para o serviço AVTransport do dispositivo DLNA.
  Future<bool> _sendSoapAction({
    required String controlUrl,
    required String action,
    required String body,
  }) async {
    try {
      final envelope = '<?xml version="1.0" encoding="utf-8"?>'
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
          's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
          '<s:Body>$body</s:Body>'
          '</s:Envelope>';

      await _dio.post(
        controlUrl,
        data: envelope,
        options: Options(
          headers: {
            'Content-Type': 'text/xml; charset="utf-8"',
            'SOAPAction': '"urn:schemas-upnp-org:service:AVTransport:1#$action"',
          },
        ),
      );
      return true;
    } catch (e) {
      AppLogger.warn('SOAP $action falhou: $e', tag: 'DLNA');
      return false;
    }
  }

  Future<bool> _castViaDlna(CastDevice device, String mediaUrl, String title) async {
    try {
      // 1. Descobre a URL de controle AVTransport
      final controlUrl = await _resolveAvTransportUrl(device);
      if (controlUrl == null) {
        AppLogger.warn(
          'AVTransport não encontrado no dispositivo ${device.name}',
          tag: 'DLNA',
        );
        state = state?.copyWith(state: CastPlaybackState.error);
        return false;
      }
      _avTransportControlUrl = controlUrl;

      // 2. SetAVTransportURI — define a mídia a ser reproduzida
      final didlMetadata =
          '&lt;DIDL-Lite xmlns=&quot;urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/&quot; '
          'xmlns:dc=&quot;http://purl.org/dc/elements/1.1/&quot; '
          'xmlns:upnp=&quot;urn:schemas-upnp-org:metadata-1-0/upnp/&quot;&gt;'
          '&lt;item id=&quot;0&quot; parentID=&quot;0&quot; restricted=&quot;1&quot;&gt;'
          '&lt;dc:title&gt;$title&lt;/dc:title&gt;'
          '&lt;upnp:class&gt;object.item.videoItem&lt;/upnp:class&gt;'
          '&lt;res protocolInfo=&quot;http-get:*:video/mp4:*&quot;&gt;$mediaUrl&lt;/res&gt;'
          '&lt;/item&gt;&lt;/DIDL-Lite&gt;';

      final setUriOk = await _sendSoapAction(
        controlUrl: controlUrl,
        action: 'SetAVTransportURI',
        body: '<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'
            '<InstanceID>0</InstanceID>'
            '<CurrentURI>$mediaUrl</CurrentURI>'
            '<CurrentURIMetaData>$didlMetadata</CurrentURIMetaData>'
            '</u:SetAVTransportURI>',
      );

      if (!setUriOk) {
        state = state?.copyWith(state: CastPlaybackState.error);
        return false;
      }

      // 3. Play — inicia a reprodução na TV
      final playOk = await _sendSoapAction(
        controlUrl: controlUrl,
        action: 'Play',
        body: '<u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'
            '<InstanceID>0</InstanceID>'
            '<Speed>1</Speed>'
            '</u:Play>',
      );

      if (playOk) {
        AppLogger.info(
          'DLNA Play enviado para ${device.name} ($controlUrl)',
          tag: 'DLNA',
        );
        state = state?.copyWith(state: CastPlaybackState.playing);
        return true;
      } else {
        state = state?.copyWith(state: CastPlaybackState.error);
        return false;
      }
    } catch (e) {
      AppLogger.warn('Falha ao transmitir via DLNA: $e', tag: 'DLNA');
      state = state?.copyWith(state: CastPlaybackState.error);
      return false;
    }
  }

  void play() {
    _webCastServer.play();
    if (_avTransportControlUrl != null) {
      _sendSoapAction(
        controlUrl: _avTransportControlUrl!,
        action: 'Play',
        body: '<u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'
            '<InstanceID>0</InstanceID>'
            '<Speed>1</Speed>'
            '</u:Play>',
      );
    }
    state = state?.copyWith(state: CastPlaybackState.playing);
  }

  void pause() {
    _webCastServer.pause();
    if (_avTransportControlUrl != null) {
      _sendSoapAction(
        controlUrl: _avTransportControlUrl!,
        action: 'Pause',
        body: '<u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'
            '<InstanceID>0</InstanceID>'
            '</u:Pause>',
      );
    }
    state = state?.copyWith(state: CastPlaybackState.paused);
  }

  void stop() {
    if (_avTransportControlUrl != null) {
      _sendSoapAction(
        controlUrl: _avTransportControlUrl!,
        action: 'Stop',
        body: '<u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'
            '<InstanceID>0</InstanceID>'
            '</u:Stop>',
      );
    }
  }

  void seekTo(Duration position) {
    _webCastServer.seekTo(position.inSeconds.toDouble());
    if (_avTransportControlUrl != null) {
      final h = position.inHours.toString().padLeft(2, '0');
      final m = (position.inMinutes % 60).toString().padLeft(2, '0');
      final s = (position.inSeconds % 60).toString().padLeft(2, '0');
      _sendSoapAction(
        controlUrl: _avTransportControlUrl!,
        action: 'Seek',
        body: '<u:Seek xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'
            '<InstanceID>0</InstanceID>'
            '<Unit>REL_TIME</Unit>'
            '<Target>$h:$m:$s</Target>'
            '</u:Seek>',
      );
    }
    state = state?.copyWith(position: position);
  }

  void setVolume(double volume) {
    _webCastServer.setVolume(volume);
    state = state?.copyWith(volume: volume);
  }

  void disconnect() {
    stop();
    _webCastServer.stop();
    _avTransportControlUrl = null;
    state = null;
  }
}

