import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_typography.dart';
import '../../../core/localization/app_localization.dart';
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
              notice: context.tr('auth.notice_confirm'),
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
              notice: context.tr('auth.notice_recovery'),
            );
          }
        case _Step.recoveryCode:
          await repository.verifyRecovery(_email.text, _code.text);
          if (mounted) _changeStep(_Step.newPassword);
        case _Step.newPassword:
          await repository.updatePassword(_password.text);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('auth.password_updated'))),
            );
            await _finish();
          }
      }
    } catch (error) {
      final message = accountErrorMessage(error);
      if (mounted) {
        if (error is AuthException && error.code == 'email_not_confirmed') {
          _changeStep(
            _Step.confirm,
            notice: context.tr('auth.notice_email_confirm'),
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
        setState(() => _notice = context.tr('auth.notice_resend'));
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
        ? context.tr('auth.title_login')
        : switch (_step) {
            _Step.login => context.tr('auth.title_login'),
            _Step.signup => context.tr('auth.title_signup'),
            _Step.confirm => context.tr('auth.title_confirm'),
            _Step.forgot ||
            _Step.recoveryCode => context.tr('auth.title_recover'),
            _Step.newPassword => context.tr('auth.title_new_password'),
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
                  tooltip: context.tr('auth.back_options'),
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
                constraints: BoxConstraints(maxWidth: isTvChoice ? 740 : 480),
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
                              context.tr('auth.unavailable'),
                              style: AppTypography.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('auth.unavailable_description'),
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
          context.tr('auth.tv_welcome'),
          style: AppTypography.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('auth.tv_choose'),
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
              badge: context.tr('auth.recommended'),
              icon: Icons.qr_code_2_rounded,
              title: context.tr('auth.qr_title'),
              subtitle: context.tr('auth.qr_description'),
              buttonLabel: context.tr('auth.connect_android'),
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
              title: context.tr('auth.manual_title'),
              subtitle: context.tr('auth.manual_description'),
              buttonLabel: context.tr('auth.enter_credentials'),
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
              children: [cardQr, const SizedBox(height: 18), cardManual],
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
                  label: Text(context.tr('auth.back_qr')),
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
                  ? context.tr('auth.intro_account')
                  : context.tr('auth.intro_favorites'),
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
                  decoration: InputDecoration(
                    labelText: context.tr('auth.name'),
                  ),
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
                  decoration: InputDecoration(
                    labelText: context.tr('auth.email'),
                  ),
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
                    labelText: context.tr(
                      newPassword ? 'auth.new_password' : 'auth.password',
                    ),
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? context.tr('auth.show_password')
                          : context.tr('auth.hide_password'),
                      onPressed: _busy
                          ? null
                          : () =>
                                setState(() => _hidePassword = !_hidePassword),
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
                            ? context.tr('auth.password_required')
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
                  decoration: InputDecoration(
                    labelText: context.tr('auth.confirm_password'),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) => value == _password.text
                      ? null
                      : context.tr('auth.passwords_mismatch'),
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
                  decoration: InputDecoration(
                    labelText: context.tr('auth.email_code'),
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofillHints: const [AutofillHints.oneTimeCode],
                  validator: (value) =>
                      RegExp(r'^\d{6,10}$').hasMatch(value ?? '')
                      ? null
                      : context.tr('auth.enter_code'),
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_notice!, style: AppTypography.bodySmall),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(switch (_step) {
                        _Step.login => context.tr('auth.login'),
                        _Step.signup => context.tr('auth.create_account'),
                        _Step.confirm ||
                        _Step.recoveryCode => context.tr('auth.confirm_code'),
                        _Step.forgot => context.tr('auth.send_code'),
                        _Step.newPassword => context.tr('auth.save_password'),
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
                  child: Text(context.tr('auth.forgot_password')),
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
                  child: Text(context.tr('auth.create_account')),
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
                  child: Text(context.tr('auth.resend_code')),
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
                        ? context.tr('auth.have_account')
                        : context.tr('auth.back_login'),
                  ),
                ),
              ),
            if (isTv && (_step == _Step.login || _step == _Step.signup))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TvFocusableButton(
                  onPressed: _busy ? null : () => context.push('/tv-pair'),
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => context.push('/tv-pair'),
                    icon: const Icon(Icons.qr_code_2),
                    label: Text(context.tr('auth.connect_android')),
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
