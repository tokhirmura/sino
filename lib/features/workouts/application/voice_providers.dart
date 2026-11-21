import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/storage/prefs.dart';
import '../data/voice.dart';
import 'voice_coach.dart';

/// The voice setting of the player (prefs `workouts.voice`, «auto» by
/// default).
class VoiceChoiceNotifier extends Notifier<VoiceChoice> {
  static const key = 'workouts.voice';

  @override
  VoiceChoice build() =>
      VoiceChoice.fromName(ref.watch(sharedPreferencesProvider).getString(key));

  Future<void> set(VoiceChoice choice) async {
    state = choice;
    await ref.read(sharedPreferencesProvider).setString(key, choice.name);
  }
}

final voiceChoiceProvider = NotifierProvider<VoiceChoiceNotifier, VoiceChoice>(
  VoiceChoiceNotifier.new,
);

/// Voices this phone has (asked once).
final voiceLangsProvider = FutureProvider<Set<VoiceLang>>(
  (ref) => ref.watch(speakerProvider).available(),
);

/// The language the player speaks now; `null` — silent.
final activeVoiceProvider = Provider<VoiceLang?>(
  (ref) => resolveVoice(
    ref.watch(voiceChoiceProvider),
    ref.watch(appLangProvider),
    ref.watch(voiceLangsProvider).value ?? const {},
  ),
);
