import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/prefs.dart';

/// Developer mode: unlocked by tapping the version line 7 times.
/// Shows demo-only tools (e.g. sample data seeding).
class DevModeNotifier extends Notifier<bool> {
  static const key = 'profile.dev_mode';
  static const tapsToUnlock = 7;

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(key) ?? false;

  Future<void> toggle() async {
    state = !state;
    await ref.read(sharedPreferencesProvider).setBool(key, state);
  }
}

final devModeProvider = NotifierProvider<DevModeNotifier, bool>(
  DevModeNotifier.new,
);
