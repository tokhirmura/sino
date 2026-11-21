import 'package:flutter_test/flutter_test.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/features/workouts/application/voice_coach.dart';
import 'package:sino/features/workouts/application/workout_run.dart';
import 'package:sino/features/workouts/data/models.dart';

const _plank = Exercise(
  id: 'plank',
  type: WorkoutType.home,
  name: {'uz': 'Planka', 'ru': 'Планка', 'en': 'Plank'},
  seconds: 20,
);
const _push = Exercise(
  id: 'push',
  type: WorkoutType.home,
  name: {'uz': 'Otjimaniya', 'ru': 'Отжимания', 'en': 'Push-ups'},
  reps: 3,
);

/// Plank 1 × 20 s, rest 10 s, push-ups 1 × 3.
WorkoutRun _run() => WorkoutRun.start(
  buildSteps(
    const PlanDay(
      day: 1,
      items: [
        PlanItem(exerciseId: 'plank', sets: 1, seconds: 20),
        PlanItem(exerciseId: 'push', sets: 1, reps: 3),
      ],
      minutes: 2,
      kcal: 10,
    ),
    {'plank': _plank, 'push': _push},
    restSeconds: 10,
  ),
);

/// Every phrase said while ticking [n] seconds from [run].
(WorkoutRun, List<String>) _tick(WorkoutRun run, int n, VoiceLang lang) {
  final said = <String>[];
  for (var i = 0; i < n; i++) {
    final next = run.tick();
    said.addAll(cues(run, next, lang));
    run = next;
  }
  return (run, said);
}

void main() {
  group('resolveVoice', () {
    const all = {VoiceLang.uz, VoiceLang.ru, VoiceLang.en};
    const noUz = {VoiceLang.ru, VoiceLang.en};

    test('auto follows the app language', () {
      expect(resolveVoice(VoiceChoice.auto, AppLang.uz, all), VoiceLang.uz);
      expect(resolveVoice(VoiceChoice.auto, AppLang.ru, all), VoiceLang.ru);
      expect(resolveVoice(VoiceChoice.auto, AppLang.en, all), VoiceLang.en);
    });

    test('no Uzbek voice on the phone → Russian, then English', () {
      expect(resolveVoice(VoiceChoice.auto, AppLang.uz, noUz), VoiceLang.ru);
      expect(resolveVoice(VoiceChoice.uz, AppLang.en, noUz), VoiceLang.ru);
      expect(
        resolveVoice(VoiceChoice.uz, AppLang.uz, {VoiceLang.en}),
        VoiceLang.en,
      );
    });

    test('a chosen language wins over the app language', () {
      expect(resolveVoice(VoiceChoice.ru, AppLang.uz, all), VoiceLang.ru);
    });

    test('off or no voices at all → silent', () {
      expect(resolveVoice(VoiceChoice.off, AppLang.uz, all), isNull);
      expect(resolveVoice(VoiceChoice.auto, AppLang.uz, const {}), isNull);
    });

    test('unknown setting in prefs → auto', () {
      expect(VoiceChoice.fromName('loud'), VoiceChoice.auto);
      expect(VoiceChoice.fromName('ru'), VoiceChoice.ru);
    });
  });

  test('numbers as words', () {
    expect(
      [for (var n = 1; n <= 10; n++) numberWord(n, VoiceLang.uz)],
      [
        'bir', 'ikki', 'uch', "to'rt", 'besh', //
        'olti', 'yetti', 'sakkiz', "to'qqiz", "o'n",
      ],
    );
    expect(numberWord(11, VoiceLang.uz), "o'n bir");
    expect(numberWord(20, VoiceLang.uz), 'yigirma');
    expect(numberWord(42, VoiceLang.uz), 'qirq ikki');
    expect(numberWord(1, VoiceLang.ru), 'раз');
    expect(numberWord(12, VoiceLang.ru), 'двенадцать');
    expect(numberWord(21, VoiceLang.ru), 'двадцать один');
    expect(numberWord(35, VoiceLang.ru), 'тридцать пять');
    expect(numberWord(42, VoiceLang.en), 'forty-two');
    expect(numberWord(99, VoiceLang.en), 'ninety-nine');
  });

  group('cues', () {
    test('a whole workout in Uzbek', () {
      var run = _run();
      expect(
        startCue(run, VoiceLang.uz),
        'Tayyorlaning. Birinchi mashq: Planka',
      );

      // Get ready 5 s: «uch, ikki, bir», then the first exercise.
      final (r1, ready) = _tick(run, 5, VoiceLang.uz);
      expect(ready, ['uch', 'ikki', 'bir', 'Planka. 20 soniya. Boshladik!']);
      run = r1;

      // Plank 20 s: halfway, «uch, ikki, bir», then rest with what's next.
      final (r2, plank) = _tick(run, 20, VoiceLang.uz);
      expect(plank, [
        "Yarmi o'tdi",
        'uch',
        'ikki',
        'bir',
        'Dam oling. Keyingisi: Otjimaniya',
      ]);
      run = r2;

      // Rest 10 s → push-ups.
      final (r3, rest) = _tick(run, 10, VoiceLang.uz);
      expect(rest, ['uch', 'ikki', 'bir', 'Otjimaniya. 3 marta. Boshladik!']);
      run = r3;

      // Reps: one every 3 s — «bir, ikki, uch», then a nudge, then quiet.
      final (r4, reps) = _tick(run, 15, VoiceLang.uz);
      expect(reps, ['bir', 'ikki', 'uch', "Ofarin! «Bajarildi»ni bosing"]);
      run = r4;

      final done = run.completeSet();
      expect(cues(run, done, VoiceLang.uz), ["Mashg'ulot tugadi! Barakalla!"]);
      expect(cues(done, done, VoiceLang.uz), isEmpty);
    });

    test('Russian phrases and exercise names', () {
      final run = _run();
      final (_, said) = _tick(run, 5, VoiceLang.ru);
      expect(said, ['три', 'два', 'раз', 'Планка. 20 секунд. Начали!']);
    });

    test('paused or stopped with nothing done — silent', () {
      final run = _run();
      final paused = run.togglePause();
      expect(cues(run, paused, VoiceLang.uz), isEmpty);
      expect(cues(paused, paused.tick(), VoiceLang.uz), isEmpty);
      expect(cues(run, run.finish(), VoiceLang.uz), isEmpty);
    });

    test('skipping the rest announces the next exercise', () {
      var run = _run().skip(); // → plank
      run = run.completeSet(); // → rest
      final next = run.skip();
      expect(cues(run, next, VoiceLang.en), ['Push-ups. 3 reps. Go!']);
    });
  });
}
