import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../application/voice_coach.dart';

/// Text-to-speech of the player (S2-4).
abstract class Speaker {
  /// Languages the phone can speak (empty — no TTS, e.g. in tests).
  Future<Set<VoiceLang>> available();

  /// Says [text] in [lang], cutting off what is still being said.
  Future<void> say(String text, VoiceLang lang);

  Future<void> stop();
}

/// `flutter_tts`: Android TextToSpeech / iOS AVSpeechSynthesizer.
class FlutterTtsSpeaker implements Speaker {
  FlutterTts? _tts;
  VoiceLang? _lang;

  Future<FlutterTts> _engine() async {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = FlutterTts();
    _tts = tts;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Over music: lower it while speaking, never stop it.
      await tts.setSharedInstance(true);
      await tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ]);
    }
    return tts;
  }

  @override
  Future<Set<VoiceLang>> available() async {
    try {
      final tts = await _engine();
      final found = <VoiceLang>{};
      for (final l in VoiceLang.values) {
        final ok = await tts.isLanguageAvailable(l.locale);
        if (ok == true || ok == 1) found.add(l);
      }
      if (found.isEmpty) {
        // Some engines answer only through the language list.
        final all = await tts.getLanguages;
        final codes = [
          for (final x in (all as List?) ?? const [])
            x.toString().toLowerCase(),
        ];
        for (final l in VoiceLang.values) {
          if (codes.any((c) => c.startsWith(l.name))) found.add(l);
        }
      }
      return found;
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<void> say(String text, VoiceLang lang) async {
    try {
      final tts = await _engine();
      if (_lang != lang) {
        await tts.setLanguage(lang.locale);
        _lang = lang;
      }
      await tts.speak(text);
    } catch (_) {
      // A voice is a bonus: never break the workout over it.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

/// Test double: remembers what was said.
class FakeSpeaker implements Speaker {
  FakeSpeaker([this.langs = const {VoiceLang.ru, VoiceLang.en}]);

  final Set<VoiceLang> langs;
  final said = <(VoiceLang, String)>[];
  int stops = 0;

  @override
  Future<Set<VoiceLang>> available() async => langs;

  @override
  Future<void> say(String text, VoiceLang lang) async => said.add((lang, text));

  @override
  Future<void> stop() async => stops++;
}

final speakerProvider = Provider<Speaker>((ref) => FlutterTtsSpeaker());
