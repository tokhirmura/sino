import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/prefs.dart';

/// Intro slides are shown once; after sign-out the user lands on sign-in.
class IntroSeenNotifier extends Notifier<bool> {
  static const key = 'onboarding.intro_seen';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(key) ?? false;

  Future<void> markSeen() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(key, true);
  }
}

final introSeenProvider = NotifierProvider<IntroSeenNotifier, bool>(
  IntroSeenNotifier.new,
);
