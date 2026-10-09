import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/account_messages.dart';
import '../services/account_repository.dart';
import 'tv_auth_widgets.dart';

enum _Step { login, signup, confirm, forgot, recoveryCode, newPassword }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.requireAccount = false,
    this.startWithSignup = false,
    this.isTv = false,
  });

  final bool requireAccount;
  final bool startWithSignup;
  final bool isTv;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  var _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeatPassword = TextEditingController();
  final _code = TextEditingController();

  // FocusNodes dedicados para navegação perfeita via D-pad em Android TV
  final _nameFocus = FocusNode(debugLabel: 'name');
  final _emailFocus = FocusNode(debugLabel: 'email');
  final _passwordFocus = FocusNode(debugLabel: 'password');
  final _repeatPasswordFocus = FocusNode(debugLabel: 'repeat_password');
  final _codeFocus = FocusNode(debugLabel: 'code');
  final _submitFocus = FocusNode(debugLabel: 'submit');
  final _forgotFocus = FocusNode(debugLabel: 'forgot');
  final _toggleFocus = FocusNode(debugLabel: 'toggle');
  final _backToChoiceFocus = FocusNode(debugLabel: 'back_to_choice');
  final _qrChoiceFocus = FocusNode(debugLabel: 'qr_choice');
  final _manualChoiceFocus = FocusNode(debugLabel: 'manual_choice');

  _Step _step = _Step.login;
  bool _busy = false;
  bool _hidePassword = true;
  bool _showTvChoice = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    if (widget.startWithSignup) _step = _Step.signup;
    if (widget.isTv) {
      _showTvChoice = true;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _password,
      _repeatPassword,
      _code,
    ]) {
      controller.dispose();
    }
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _repeatPasswordFocus.dispose();
    _codeFocus.dispose();
    _submitFocus.dispose();
    _forgotFocus.dispose();
    _toggleFocus.dispose();
    _backToChoiceFocus.dispose();
    _qrChoiceFocus.dispose();
    _manualChoiceFocus.dispose();
    super.dispose();
  }

  void _changeStep(_Step step, {String? notice}) {
    setState(() {
      _step = step;
      _form = GlobalKey<FormState>();
      _error = null;
      _notice = notice;
      _hidePassword = true;
      _password.clear();
      _repeatPassword.clear();
      _code.clear();
    });

    if (widget.isTv) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (step == _Step.signup) {
          _nameFocus.requestFocus();
        } else if (step == _Step.confirm || step == _Step.recoveryCode) {
          _codeFocus.requestFocus();
        } else {
          _emailFocus.requestFocus();
        }
      });
    }
  }

  void _openManualEntry() {
    setState(() {
      _showTvChoice = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_step == _Step.signup) {
        _nameFocus.requestFocus();
      } else {
        _emailFocus.requestFocus();
      }
    });
  }

  void _backToTvChoice() {
    setState(() {
      _showTvChoice = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _qrChoiceFocus.requestFocus();
    });
  }

  Future<void> _finish() async {
    TextInput.finishAutofillContext();
    if (widget.requireAccount) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      context.go(
        prefs.getBool('onboarding_completed') == true ? '/home' : '/onboarding',
      );
    } else if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/profile');
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final repository = ref.read(accountRepositoryProvider);
    try {
      switch (_step) {
        case _Step.login:
          await repository.signIn(_email.text, _password.text);
          if (mounted) await _finish();
        case _Step.signup:
          final signedIn = await repository.signUp(
            _name.text,
            _email.text,
            _password.text,
          );
          if (!mounted) return;
          if (signedIn) {
            await _finish();
          } else {
            _changeStep(
              _Step.confirm,
              notice: 'Confira seu e-mail e digite o código de confirmação.',
            );
          }
        case _Step.confirm:
          await repository.confirmEmail(_email.text, _code.text);
          if (mounted) await _finish();
        case _Step.forgot:
          await repository.requestPasswordReset(_email.text);
          if (mounted) {
            _changeStep(
              _Step.recoveryCode,
              notice:
                  'Se houver uma conta com esse e-mail, você receberá um código.',
            );
          }
        case _Step.recoveryCode:
          await repository.verifyRecovery(_email.text, _code.text);
          if (mounted) _changeStep(_Step.newPassword);
        case _Step.newPassword:
          await repository.updatePassword(_password.text);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Senha atualizada.')));
            await _finish();
          }
      }
    } catch (error) {
      final message = accountErrorMessage(error);
      if (mounted) {
        if (error is AuthException && error.code == 'email_not_confirmed') {
          _changeStep(
            _Step.confirm,
            notice:
                'Confirme seu e-mail. Se precisar, solicite um novo código.',
          );
        } else {
          setState(() => _error = message);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final repository = ref.read(accountRepositoryProvider);
      if (_step == _Step.confirm) {
        await repository.resendConfirmation(_email.text);
      } else {
        await repository.requestPasswordReset(_email.text);
      }
      if (mounted) {
        setState(
          () => _notice =
              'Se o e-mail estiver correto e elegível, um novo código será enviado.',
        );
      }
    } catch (error) {
      final message = accountErrorMessage(error);
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(accountRepositoryProvider).isConfigured;
    final isTvChoice = widget.isTv && _showTvChoice;

    final title = isTvChoice
        ? 'Entrar no CiNey'
        : switch (_step) {
            _Step.login => 'Entrar no CiNey',
            _Step.signup => 'Criar sua conta',
            _Step.confirm => 'Confirmar e-mail',
            _Step.forgot || _Step.recoveryCode => 'Recuperar senha',
            _Step.newPassword => 'Escolher nova senha',
          };
    final codeStep = _step == _Step.confirm || _step == _Step.recoveryCode;
    final newPassword = _step == _Step.signup || _step == _Step.newPassword;

    return PopScope(
      canPop: !_busy && (!widget.isTv || _showTvChoice),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (widget.isTv && !_showTvChoice && !_busy) {
          _backToTvChoice();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.requireAccount && !widget.isTv,
          leading: widget.isTv && !isTvChoice
              ? IconButton(
                  focusNode: _backToChoiceFocus,
                  tooltip: 'Voltar para opções',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _busy ? null : _backToTvChoice,
                )
              : null,
          title: Text(title, style: AppTypography.headlineMedium),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTvChoice ? 740 : 480,
                ),
                child: GlassCard(
                  child: !configured
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person_outline,
                              color: AppColors.primary,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Contas ainda indisponíveis',
                              style: AppTypography.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Você precisa entrar na sua conta para usar o CiNey. Reabra o app para tentar novamente.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : isTvChoice
                          ? _buildTvChoiceView(context)
                          : _buildFormView(context, codeStep, newPassword),
                ).animate().fadeIn(duration: 180.ms),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tela com 2 opções de escolha na TV (QR Code ou Manual)
  Widget _buildTvChoiceView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.movie_filter_outlined,
          color: AppColors.primary,
          size: 56,
        ),
        const SizedBox(height: 16),
        Text(
          'Bem-vindo ao CiNey na TV',
          style: AppTypography.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Escolha como deseja se conectar para acessar seus filmes e séries:',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 540;
            final cardQr = TvChoiceCard(
              focusNode: _qrChoiceFocus,
              autofocus: true,
              badge: 'RECOMENDADO',
              icon: Icons.qr_code_2_rounded,
              title: 'Entrar via QR Code',
              subtitle:
                  'Abra o CiNey no celular (Perfil > Conectar TV) e escaneie a tela para entrar instantaneamente sem digitar.',
              buttonLabel: 'Conectar com Android',
              onTap: () => context.push('/tv-pair'),
              onKey: (event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                      event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _manualChoiceFocus.requestFocus();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
            );

            final cardManual = TvChoiceCard(
              focusNode: _manualChoiceFocus,
              icon: Icons.keyboard_alt_outlined,
              title: 'Entrar manualmente',
              subtitle:
                  'Digite seu e-mail e senha diretamente na TV usando as teclas do controle remoto.',
              buttonLabel: 'Digitar dados de acesso',
              onTap: _openManualEntry,
              onKey: (event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                      event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _qrChoiceFocus.requestFocus();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cardQr),
                  const SizedBox(width: 20),
                  Expanded(child: cardManual),
                ],
              );
            }

            return Column(
              children: [
                cardQr,
                const SizedBox(height: 18),
                cardManual,
              ],
            );
          },
        ),
      ],
    );
  }

  /// Formulário de login/cadastro com suporte refinado para D-Pad da TV
  Widget _buildFormView(BuildContext context, bool codeStep, bool newPassword) {
    final isTv = widget.isTv;

    return AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isTv) ...[
              TvFocusableButton(
                focusNode: _backToChoiceFocus,
                onPressed: _busy ? null : _backToTvChoice,
                onDownPressed: () {
                  if (_step == _Step.signup) {
                    _nameFocus.requestFocus();
                  } else if (codeStep) {
                    _codeFocus.requestFocus();
                  } else {
                    _emailFocus.requestFocus();
                  }
                },
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _backToTvChoice,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Voltar para opções (QR Code)'),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              const Icon(
                Icons.movie_filter_outlined,
                color: AppColors.primary,
                size: 48,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              widget.requireAccount
                  ? 'Crie sua conta ou entre para usar o CiNey.'
                  : 'Seus favoritos no celular e na TV.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_step == _Step.signup) ...[
              _wrapField(
                focusNode: _nameFocus,
                onDown: () => _emailFocus.requestFocus(),
                onUp: isTv ? () => _backToChoiceFocus.requestFocus() : null,
                child: TextFormField(
                  key: const ValueKey('name'),
                  controller: _name,
                  focusNode: _nameFocus,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  textInputAction: TextInputAction.next,
                  maxLength: 60,
                  autofillHints: const [AutofillHints.name],
                  validator: validateDisplayName,
                  onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_step != _Step.newPassword) ...[
              _wrapField(
                focusNode: _emailFocus,
                onDown: () {
                  if (_step == _Step.login || newPassword) {
                    _passwordFocus.requestFocus();
                  } else if (codeStep) {
                    _codeFocus.requestFocus();
                  } else {
                    _submitFocus.requestFocus();
                  }
                },
                onUp: () {
                  if (_step == _Step.signup) {
                    _nameFocus.requestFocus();
                  } else if (isTv) {
                    _backToChoiceFocus.requestFocus();
                  }
                },
                child: TextFormField(
                  key: const ValueKey('email'),
                  controller: _email,
                  focusNode: _emailFocus,
                  enabled: !_busy && !codeStep,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: validateEmail,
                  onFieldSubmitted: (_) {
                    if (_step == _Step.login || newPassword) {
                      _passwordFocus.requestFocus();
                    } else {
                      _submit();
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_step == _Step.login || newPassword) ...[
              _wrapField(
                focusNode: _passwordFocus,
                onDown: () {
                  if (newPassword) {
                    _repeatPasswordFocus.requestFocus();
                  } else {
                    _submitFocus.requestFocus();
                  }
                },
                onUp: () {
                  if (_step != _Step.newPassword) {
                    _emailFocus.requestFocus();
                  } else if (isTv) {
                    _backToChoiceFocus.requestFocus();
                  }
                },
                child: TextFormField(
                  key: ValueKey('password-$_step'),
                  controller: _password,
                  focusNode: _passwordFocus,
                  enabled: !_busy,
                  obscureText: _hidePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: newPassword ? 'Nova senha' : 'Senha',
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? 'Mostrar senha'
                          : 'Ocultar senha',
                      onPressed: _busy
                          ? null
                          : () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  autofillHints: [
                    newPassword
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  textInputAction: newPassword
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onFieldSubmitted: newPassword
                      ? (_) => _repeatPasswordFocus.requestFocus()
                      : (_) => _submit(),
                  validator: newPassword
                      ? validateNewPassword
                      : (value) => value == null || value.isEmpty
                          ? 'Informe sua senha.'
                          : null,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (newPassword) ...[
              _wrapField(
                focusNode: _repeatPasswordFocus,
                onDown: () => _submitFocus.requestFocus(),
                onUp: () => _passwordFocus.requestFocus(),
                child: TextFormField(
                  key: const ValueKey('repeat-password'),
                  controller: _repeatPassword,
                  focusNode: _repeatPasswordFocus,
                  enabled: !_busy,
                  obscureText: _hidePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar senha',
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) => value == _password.text
                      ? null
                      : 'As senhas precisam ser iguais.',
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (codeStep) ...[
              _wrapField(
                focusNode: _codeFocus,
                onDown: () => _submitFocus.requestFocus(),
                onUp: () => _emailFocus.requestFocus(),
                child: TextFormField(
                  key: const ValueKey('code'),
                  controller: _code,
                  focusNode: _codeFocus,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Código recebido por e-mail',
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  autofillHints: const [
                    AutofillHints.oneTimeCode,
                  ],
                  validator: (value) =>
                      RegExp(r'^\d{6,10}$').hasMatch(value ?? '')
                          ? null
                          : 'Digite o código recebido.',
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _notice!,
                  style: AppTypography.bodySmall,
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            _wrapButton(
              focusNode: _submitFocus,
              onPressed: _busy ? null : _submit,
              onUp: () {
                if (newPassword) {
                  _repeatPasswordFocus.requestFocus();
                } else if (_step == _Step.login) {
                  _passwordFocus.requestFocus();
                } else if (codeStep) {
                  _codeFocus.requestFocus();
                } else {
                  _emailFocus.requestFocus();
                }
              },
              onDown: () {
                if (_step == _Step.login) {
                  _forgotFocus.requestFocus();
                } else {
                  _toggleFocus.requestFocus();
                }
              },
              child: FilledButton(
                focusNode: isTv ? null : _submitFocus,
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Text(switch (_step) {
                        _Step.login => 'Entrar',
                        _Step.signup => 'Criar conta',
                        _Step.confirm || _Step.recoveryCode =>
                          'Confirmar código',
                        _Step.forgot => 'Enviar código',
                        _Step.newPassword => 'Salvar nova senha',
                      }),
              ),
            ),
            if (_step == _Step.login) ...[
              _wrapButton(
                focusNode: _forgotFocus,
                onPressed: _busy ? null : () => _changeStep(_Step.forgot),
                onUp: () => _submitFocus.requestFocus(),
                onDown: () => _toggleFocus.requestFocus(),
                child: TextButton(
                  focusNode: isTv ? null : _forgotFocus,
                  onPressed: _busy ? null : () => _changeStep(_Step.forgot),
                  child: const Text('Esqueci minha senha'),
                ),
              ),
              _wrapButton(
                focusNode: _toggleFocus,
                onPressed: _busy ? null : () => _changeStep(_Step.signup),
                onUp: () => _forgotFocus.requestFocus(),
                onDown: isTv ? () => _backToChoiceFocus.requestFocus() : null,
                child: OutlinedButton(
                  focusNode: isTv ? null : _toggleFocus,
                  onPressed: _busy ? null : () => _changeStep(_Step.signup),
                  child: const Text('Criar conta'),
                ),
              ),
            ],
            if (codeStep)
              _wrapButton(
                focusNode: _toggleFocus,
                onPressed: _busy ? null : _resend,
                onUp: () => _submitFocus.requestFocus(),
                onDown: isTv ? () => _backToChoiceFocus.requestFocus() : null,
                child: TextButton(
                  focusNode: isTv ? null : _toggleFocus,
                  onPressed: _busy ? null : _resend,
                  child: const Text('Reenviar código'),
                ),
              ),
            if (_step != _Step.login)
              _wrapButton(
                focusNode: _toggleFocus,
                onPressed: _busy ? null : () => _changeStep(_Step.login),
                onUp: () => _submitFocus.requestFocus(),
                onDown: isTv ? () => _backToChoiceFocus.requestFocus() : null,
                child: TextButton(
                  focusNode: isTv ? null : _toggleFocus,
                  onPressed: _busy ? null : () => _changeStep(_Step.login),
                  child: Text(
                    _step == _Step.signup
                        ? 'Já tenho uma conta'
                        : 'Voltar para entrar',
                  ),
                ),
              ),
            if (isTv &&
                (_step == _Step.login || _step == _Step.signup))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TvFocusableButton(
                  onPressed: _busy ? null : () => context.push('/tv-pair'),
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => context.push('/tv-pair'),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Conectar com Android'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _wrapField({
    required Widget child,
    required FocusNode focusNode,
    VoidCallback? onDown,
    VoidCallback? onUp,
  }) {
    if (!widget.isTv) return child;
    return TvFormFieldFocusContainer(
      focusNode: focusNode,
      onDownPressed: onDown,
      onUpPressed: onUp,
      child: child,
    );
  }

  Widget _wrapButton({
    required Widget child,
    required FocusNode focusNode,
    required VoidCallback? onPressed,
    VoidCallback? onDown,
    VoidCallback? onUp,
  }) {
    if (!widget.isTv) return child;
    return TvFocusableButton(
      focusNode: focusNode,
      onPressed: onPressed,
      onDownPressed: onDown,
      onUpPressed: onUp,
      child: child,
    );
  }
}
