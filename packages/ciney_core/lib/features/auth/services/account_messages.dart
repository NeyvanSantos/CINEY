import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/app_logger.dart';

String accountErrorMessage(Object error) {
  // Raw auth errors may include personal data. Keep them out of the log viewer.
  AppLogger.warn(
    'Operação de conta não concluída (${error.runtimeType}).',
    tag: 'ACCOUNT',
  );
  if (error is AuthException) {
    return switch (error.code) {
      'invalid_credentials' => 'E-mail ou senha incorretos.',
      'email_not_confirmed' => 'Confirme seu e-mail antes de entrar.',
      'user_already_exists' || 'email_exists' =>
        'Este e-mail já está cadastrado. Entre ou recupere sua senha.',
      'weak_password' =>
        'Escolha uma senha mais forte, com letras, números e símbolos.',
      'same_password' => 'Escolha uma senha diferente da atual.',
      'otp_expired' => 'Código inválido ou expirado. Solicite outro código.',
      'over_email_send_rate_limit' || 'over_request_rate_limit' =>
        'Aguarde um pouco antes de tentar novamente.',
      'session_not_found' ||
      'refresh_token_not_found' => 'Sua sessão expirou. Entre novamente.',
      _ => 'Não foi possível concluir. Confira os dados e tente novamente.',
    };
  }
  return 'Não foi possível conectar. Confira sua conexão e tente novamente.';
}

String? validateEmail(String? value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Informe um e-mail válido.';

String? validateNewPassword(String? value) =>
    (value?.length ?? 0) >= 8 ? null : 'Use pelo menos 8 caracteres.';

String? validateDisplayName(String? value) {
  final length = value?.trim().length ?? 0;
  return length >= 2 && length <= 60 ? null : 'Use entre 2 e 60 caracteres.';
}
