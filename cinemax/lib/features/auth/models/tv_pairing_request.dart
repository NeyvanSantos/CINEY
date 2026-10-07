class TvPairingRequest {
  const TvPairingRequest({
    required this.id,
    required this.secret,
    required this.expiresAt,
  });

  final String id;
  final String secret;
  final DateTime expiresAt;

  String get qrPayload => Uri(
    scheme: 'ciney',
    host: 'tv-pair',
    queryParameters: {'id': id, 'secret': secret},
  ).toString();

  factory TvPairingRequest.fromJson(Map<String, dynamic> json) {
    return TvPairingRequest(
      id: json['id'] as String,
      secret: json['secret'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}
