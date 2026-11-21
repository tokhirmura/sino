/// Voice coach of the player (Sprint 2.0, S2-4), without Flutter: which
/// language to speak and what to say on every step of a [WorkoutRun].
library;

import '../../../core/l10n/app_lang.dart';
import 'workout_math.dart';
import 'workout_run.dart';

/// A language the phone can speak.
enum VoiceLang {
  uz('uz-UZ'),
  ru('ru-RU'),
  en('en-US');

  const VoiceLang(this.locale);

  /// TTS locale.
  final String locale;
}

/// The setting (prefs `workouts.voice`).
enum VoiceChoice {
  /// The app language; Uzbek without an Uzbek voice → Russian.
  auto,
  uz,
  ru,
  en,
  off;

  static VoiceChoice fromName(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => auto);
}

/// What to speak, given the [choice], the app language and the voices the
/// phone has; `null` — silent (off, or no usable voice).
///
/// Uzbek is often missing on phones: then Russian (widely understood),
/// then English.
VoiceLang? resolveVoice(
  VoiceChoice choice,
  AppLang app,
  Set<VoiceLang> available,
) {
  final wanted = switch (choice) {
    VoiceChoice.off => null,
    VoiceChoice.uz => VoiceLang.uz,
    VoiceChoice.ru => VoiceLang.ru,
    VoiceChoice.en => VoiceLang.en,
    VoiceChoice.auto => switch (app) {
      AppLang.uz => VoiceLang.uz,
      AppLang.ru => VoiceLang.ru,
      AppLang.en => VoiceLang.en,
    },
  };
  if (wanted == null) return null;
  if (available.contains(wanted)) return wanted;
  for (final f in _fallbacks[wanted]!) {
    if (available.contains(f)) return f;
  }
  return null;
}

const _fallbacks = {
  VoiceLang.uz: [VoiceLang.ru, VoiceLang.en],
  VoiceLang.ru: [VoiceLang.en],
  VoiceLang.en: [VoiceLang.ru],
};

/// [n] (1…99) as a word: «bir», «o'n bir», «двадцать один», «forty-two».
/// Russian counts «раз, два, три» (1 alone is «раз»).
String numberWord(int n, VoiceLang lang) {
  assert(n >= 1 && n <= 99);
  final w = _words[lang]!;
  if (n <= w.ones.length) return w.ones[n - 1];
  final tens = w.tens[n ~/ 10 - 1];
  final one = n % 10;
  if (one == 0) return tens;
  final unit = lang == VoiceLang.ru && one == 1 ? 'один' : w.ones[one - 1];
  return '$tens${lang == VoiceLang.en ? '-' : ' '}$unit';
}

typedef _Words = ({List<String> ones, List<String> tens});

/// Uzbek in Latin with a plain apostrophe — TTS engines read it best.
const Map<VoiceLang, _Words> _words = {
  VoiceLang.uz: (
    ones: [
      'bir', 'ikki', 'uch', "to'rt", 'besh', //
      'olti', 'yetti', 'sakkiz', "to'qqiz", "o'n",
    ],
    tens: [
      "o'n", 'yigirma', "o'ttiz", 'qirq', 'ellik', //
      'oltmish', 'yetmish', 'sakson', "to'qson",
    ],
  ),
  VoiceLang.ru: (
    ones: [
      'раз', 'два', 'три', 'четыре', 'пять', 'шесть', 'семь', //
      'восемь', 'девять', 'десять', 'одиннадцать', 'двенадцать',
      'тринадцать', 'четырнадцать', 'пятнадцать', 'шестнадцать',
      'семнадцать', 'восемнадцать', 'девятнадцать', 'двадцать',
    ],
    tens: [
      'десять', 'двадцать', 'тридцать', 'сорок', 'пятьдесят', //
      'шестьдесят', 'семьдесят', 'восемьдесят', 'девяносто',
    ],
  ),
  VoiceLang.en: (
    ones: [
      'one', 'two', 'three', 'four', 'five', 'six', 'seven', //
      'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen',
      'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen',
      'nineteen', 'twenty',
    ],
    tens: [
      'ten', 'twenty', 'thirty', 'forty', 'fifty', //
      'sixty', 'seventy', 'eighty', 'ninety',
    ],
  ),
};

String _name(RunStep s, VoiceLang lang) {
  final m = s.exercise.name;
  return (m[lang.name] ?? m['ru'] ?? m['uz'] ?? '').toString();
}

/// Said once when the player opens.
String startCue(WorkoutRun run, VoiceLang lang) {
  final first = run.step;
  final name = first == null ? '' : _name(first, lang);
  return switch (lang) {
    VoiceLang.uz => "Tayyorlaning. Birinchi mashq: $name",
    VoiceLang.ru => 'Приготовьтесь. Первое упражнение: $name',
    VoiceLang.en => 'Get ready. First exercise: $name',
  };
}

/// What to say going from [before] to [after] (a tick or a button);
/// empty — nothing. Several phrases are said one after another.
List<String> cues(WorkoutRun before, WorkoutRun after, VoiceLang lang) {
  if (after.paused) return const [];
  final entered = after.phase != before.phase || after.index != before.index;

  if (after.phase == RunPhase.done) {
    if (before.phase == RunPhase.done || after.setsDone == 0) return const [];
    return [
      switch (lang) {
        VoiceLang.uz => "Mashg'ulot tugadi! Barakalla!",
        VoiceLang.ru => 'Тренировка окончена! Молодец!',
        VoiceLang.en => 'Workout complete! Well done!',
      },
    ];
  }

  final step = after.step!;
  if (entered) {
    if (after.phase == RunPhase.rest) {
      final next = after.nextWork;
      final nextName = next == null ? '' : _name(next, lang);
      return [
        switch (lang) {
          VoiceLang.uz =>
            next == null ? 'Dam oling' : 'Dam oling. Keyingisi: $nextName',
          VoiceLang.ru =>
            next == null ? 'Отдохните' : 'Отдохните. Дальше: $nextName',
          VoiceLang.en => next == null ? 'Rest' : 'Rest. Next up: $nextName',
        },
      ];
    }
    if (after.phase == RunPhase.work) {
      final name = _name(step, lang);
      final reps = step.reps;
      final secs = step.workSeconds;
      return [
        switch (lang) {
          VoiceLang.uz =>
            reps != null
                ? '$name. $reps marta. Boshladik!'
                : '$name. $secs soniya. Boshladik!',
          VoiceLang.ru =>
            reps != null
                ? '$name. $reps раз. Начали!'
                : '$name. $secs секунд. Начали!',
          VoiceLang.en =>
            reps != null
                ? '$name. $reps reps. Go!'
                : '$name. $secs seconds. Go!',
        },
      ];
    }
  }

  if (after.remaining == before.remaining) return const [];

  // Countdowns: «uch, ikki, bir» at the end of get-ready, rest and a
  // timed set.
  final countdown =
      after.phase == RunPhase.ready ||
      after.phase == RunPhase.rest ||
      after.isTimedWork;
  if (countdown) {
    final r = after.remaining;
    if (r >= 1 && r <= 3) return [numberWord(r, lang)];
    if (after.isTimedWork) {
      final total = step.workSeconds!;
      if (total >= 20 && r == total ~/ 2) {
        return [
          switch (lang) {
            VoiceLang.uz => 'Yarmi o\'tdi',
            VoiceLang.ru => 'Половина',
            VoiceLang.en => 'Halfway',
          },
        ];
      }
    }
    return const [];
  }

  // A set of reps: the time counts up; one rep every [secondsPerRep] —
  // «bir, ikki, uch…» as a pace, then a nudge to press «Done».
  final reps = step.reps;
  if (after.phase == RunPhase.work && reps != null) {
    final t = after.remaining;
    if (t % secondsPerRep != 1) return const [];
    final rep = t ~/ secondsPerRep + 1;
    if (rep <= reps && rep <= 99) return [numberWord(rep, lang)];
    if (rep == reps + 1) {
      return [
        switch (lang) {
          VoiceLang.uz => "Ofarin! «Bajarildi»ni bosing",
          VoiceLang.ru => 'Отлично! Нажмите «Готово»',
          VoiceLang.en => 'Great! Tap Done',
        },
      ];
    }
  }
  return const [];
}
