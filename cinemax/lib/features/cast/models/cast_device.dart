import 'package:flutter/material.dart';

enum CastDeviceType {
  chromecast('Chromecast / Google TV', Icons.tv_rounded, 'Google Cast'),
  samsung('Samsung Smart TV', Icons.tv_rounded, 'Tizen / Smart View'),
  lg('LG Smart TV', Icons.tv_rounded, 'webOS / SmartShare'),
  roku('Roku TV / Express', Icons.tv_rounded, 'Roku ECP'),
  fireTv('Amazon Fire TV', Icons.tv_rounded, 'Fire OS'),
  dlna('Smart TV / DLNA', Icons.connected_tv_rounded, 'DLNA / UPnP'),
  webCast('Qualquer TV (Navegador Web)', Icons.language_rounded, 'Web Browser / QR Code');

  final String label;
  final IconData icon;
  final String protocol;
  const CastDeviceType(this.label, this.icon, this.protocol);
}

class CastDevice {
  final String id;
  final String name;
  final CastDeviceType type;
  final String? ipAddress;
  final int? port;
  final String? controlUrl;
  final String? location;

  const CastDevice({
    required this.id,
    required this.name,
    required this.type,
    this.ipAddress,
    this.port,
    this.controlUrl,
    this.location,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CastDevice && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum CastPlaybackState {
  idle,
  connecting,
  playing,
  paused,
  buffering,
  stopped,
  error,
}

class CastSession {
  final CastDevice device;
  final String title;
  final String mediaUrl;
  final String? posterUrl;
  final CastPlaybackState state;
  final Duration position;
  final Duration duration;
  final double volume;

  const CastSession({
    required this.device,
    required this.title,
    required this.mediaUrl,
    this.posterUrl,
    this.state = CastPlaybackState.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
  });

  CastSession copyWith({
    CastDevice? device,
    String? title,
    String? mediaUrl,
    String? posterUrl,
    CastPlaybackState? state,
    Duration? position,
    Duration? duration,
    double? volume,
  }) {
    return CastSession(
      device: device ?? this.device,
      title: title ?? this.title,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      posterUrl: posterUrl ?? this.posterUrl,
      state: state ?? this.state,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
    );
  }
}
