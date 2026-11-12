import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../data/auth_repository.dart';
import '../auth_error_text.dart';
import 'common.dart';

/// Email + password: sign in or create an account (Supabase Auth).
/// On success the router leaves onboarding by itself.
class EmailAuthView extends ConsumerStatefulWidget {
  const EmailAuthView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<EmailAuthView> createState() => _EmailAuthViewState();
}

class _EmailAuthViewState extends ConsumerState<EmailAuthView> {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _minPassword = 6;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _signUp = false;
  bool _obscure = true;
  bool _loading = false;
  Object? _error;
  bool _confirmSent = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final lang = context.lang.name;
    setState(() {
      _loading = true;
      _error = null;
      _confirmSent = false;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      if (_signUp) {
        final result = await repo.signUpWithEmail(
          email: _email.text,
          password: _password.text,
          lang: lang,
        );
        if (result == SignUpResult.confirmEmail && mounted) {
          setState(() {
            _confirmSent = true;
            _signUp = false;
          });
        }
      } else {
        await repo.signInWithEmail(
          email: _email.text,
          password: _password.text,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepHeader(
            title: context.tr(uz: 'Email orqali', ru: 'По email', en: 'Email'),
            onBack: _loading ? null : widget.onBack,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(
                            context.tr(uz: 'Kirish', ru: 'Вход', en: 'Sign in'),
                          ),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(
                            context.tr(
                              uz: 'Ro‘yxatdan o‘tish',
                              ru: 'Регистрация',
                              en: 'Sign up',
                            ),
                          ),
                        ),
                      ],
                      selected: {_signUp},
                      onSelectionChanged: _loading
                          ? null
                          : (s) => setState(() {
                              _signUp = s.first;
                              _error = null;
                            }),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _email,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) => _emailRe.hasMatch((v ?? '').trim())
                          ? null
                          : context.tr(
                              uz: 'To‘g‘ri email kiriting',
                              ru: 'Введите корректный email',
                              en: 'Enter a valid email',
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      enabled: !_loading,
                      obscureText: _obscure,
                      autofillHints: [
                        _signUp
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: context.tr(
                          uz: 'Parol',
                          ru: 'Пароль',
                          en: 'Password',
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (v) => (v ?? '').length >= _minPassword
                          ? null
                          : context.tr(
                              uz: 'Kamida $_minPassword ta belgi',
                              ru: 'Минимум $_minPassword символов',
                              en: 'At least $_minPassword characters',
                            ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      InlineMessage.error(authErrorText(context, _error!)),
                    ],
                    if (_confirmSent) ...[
                      const SizedBox(height: 16),
                      InlineMessage.info(
                        context.tr(
                          uz:
                              'Pochtangizga tasdiqlash xati yuborildi. '
                              'Havolani bosing va shu yerda kiring.',
                          ru:
                              'Мы отправили письмо для подтверждения. '
                              'Перейдите по ссылке и войдите здесь.',
                          en:
                              'We sent you a confirmation email. Open the '
                              'link, then sign in here.',
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const ButtonSpinner()
                          : Text(
                              _signUp
                                  ? context.tr(
                                      uz: 'Hisob yaratish',
                                      ru: 'Создать аккаунт',
                                      en: 'Create account',
                                    )
                                  : context.tr(
                                      uz: 'Kirish',
                                      ru: 'Войти',
                                      en: 'Sign in',
                                    ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
