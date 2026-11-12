import 'package:flutter/material.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/emoji_box.dart';
import 'common.dart';

/// Sign-in screen with three paths: OneID, email, guest.
class SignInOptions extends StatelessWidget {
  const SignInOptions({
    super.key,
    required this.onOneId,
    required this.onEmail,
    required this.onGuest,
    required this.guestLoading,
  });

  final VoidCallback onOneId;
  final VoidCallback onEmail;
  final VoidCallback onGuest;
  final bool guestLoading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: LangSwitcher(),
                ),
                const Spacer(),
                const Center(child: EmojiBox(emoji: '🌿', size: 96)),
                const SizedBox(height: 20),
                Text(
                  'Sino',
                  textAlign: TextAlign.center,
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    uz: 'Kirish usulini tanlang',
                    ru: 'Выберите способ входа',
                    en: 'Choose how to sign in',
                  ),
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
                const Spacer(),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: guestLoading ? null : onOneId,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(
                    context.tr(
                      uz: 'OneID orqali kirish',
                      ru: 'Войти через OneID',
                      en: 'Sign in with OneID',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      size: 16,
                      color: AppColors.good,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        context.tr(
                          uz: 'Davlat tomonidan tasdiqlangan profil',
                          ru: 'Профиль, подтверждённый государством',
                          en: 'Government-verified profile',
                        ),
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: wideOutlinedStyle,
                  onPressed: guestLoading ? null : onEmail,
                  icon: const Icon(Icons.mail_outline),
                  label: Text(
                    context.tr(
                      uz: 'Email orqali kirish',
                      ru: 'Войти по email',
                      en: 'Sign in with email',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: guestLoading ? null : onGuest,
                  child: guestLoading
                      ? const ButtonSpinner()
                      : Text(
                          context.tr(
                            uz: 'Mehmon sifatida davom etish',
                            ru: 'Продолжить как гость',
                            en: 'Continue as guest',
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
