import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';

/// Stub. Fake mode: «Boshlash» sets the fake session flag.
/// Real mode: tries anonymous sign-in (module A will replace with real auth).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _loading = false;

  Future<void> _start() async {
    setState(() => _loading = true);
    try {
      if (ref.read(useFakeProvider)) {
        await ref.read(fakeAuthProvider.notifier).signIn();
      } else {
        await ref.read(supabaseClientProvider).auth.signInAnonymously();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.tr(
        uz: 'Xush kelibsiz',
        ru: 'Добро пожаловать',
        en: 'Welcome',
      ),
      body: EmptyState(
        emoji: '👋',
        title: context.tr(
          uz: 'Xush kelibsiz — tez orada',
          ru: 'Добро пожаловать — скоро',
          en: 'Welcome — coming soon',
        ),
        message: 'Sino',
        action: FilledButton(
          onPressed: _loading ? null : _start,
          child: _loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr(uz: 'Boshlash', ru: 'Начать', en: 'Start')),
        ),
      ),
    );
  }
}
