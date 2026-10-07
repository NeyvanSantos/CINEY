import 'dart:convert';

class AccountConfig {
  const AccountConfig({required this.url, required this.publicKey});

  static const environment = AccountConfig(
    url: String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://fekultszwaxbzejdfluq.supabase.co',
    ),
    publicKey: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_Nykhdh_Og6lY_6aPe10r0w_pcuCrNWU',
    ),
  );

  final String url;
  final String publicKey;

  bool get isConfigured {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    if (publicKey.startsWith('sb_publishable_')) return true;
    // Accept legacy anon keys, but never embed a privileged service_role key.
    try {
      final parts = publicKey.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'anon';
    } on FormatException {
      return false;
    }
  }
}
