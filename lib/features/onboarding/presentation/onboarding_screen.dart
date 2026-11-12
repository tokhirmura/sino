import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../application/onboarding_prefs.dart';
import '../data/auth_repository.dart';
import 'auth_error_text.dart';
import 'widgets/email_auth_view.dart';
import 'widgets/intro_slides.dart';
import 'widgets/one_id_view.dart';
import 'widgets/sign_in_options.dart';

enum _Step { intro, options, email, oneId }

/// `/onboarding`: intro slides → sign-in options → email / OneID.
///
/// All steps live in one route: without a session the router redirects
/// every other path here, and as soon as a session appears it sends the
/// user to home — so no step navigates on success.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late _Step _step = ref.read(introSeenProvider) ? _Step.options : _Step.intro;
  bool _guestLoading = false;

  void _go(_Step step) => setState(() => _step = step);

  void _finishIntro() {
    ref.read(introSeenProvider.notifier).markSeen();
    _go(_Step.options);
  }

  Future<void> _continueAsGuest() async {
    final lang = context.lang.name;
    setState(() => _guestLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInAnonymously(lang: lang);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorText(context, e))));
      }
    } finally {
      if (mounted) setState(() => _guestLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inner = _step == _Step.email || _step == _Step.oneId;
    return PopScope(
      canPop: !inner,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inner) _go(_Step.options);
      },
      child: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: switch (_step) {
                _Step.intro => IntroSlides(onDone: _finishIntro),
                _Step.options => SignInOptions(
                  onOneId: () => _go(_Step.oneId),
                  onEmail: () => _go(_Step.email),
                  onGuest: _continueAsGuest,
                  guestLoading: _guestLoading,
                ),
                _Step.email => EmailAuthView(onBack: () => _go(_Step.options)),
                _Step.oneId => OneIdView(onBack: () => _go(_Step.options)),
              },
            ),
          ),
        ),
      ),
    );
  }
}
