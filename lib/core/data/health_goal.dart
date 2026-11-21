import '../l10n/app_lang.dart';

/// The user's main goal (`profiles.goal`), asked right after sign-in.
/// Home lifts the cards that help with it.
enum HealthGoal {
  loseWeight('lose_weight', '🏃'),
  energy('energy', '⚡'),
  pressureSugar('pressure_sugar', '🩺'),
  family('family', '👨‍👩‍👧');

  const HealthGoal(this.code, this.emoji);

  /// Value in `profiles.goal`.
  final String code;
  final String emoji;

  static HealthGoal? byCode(Object? code) {
    for (final g in values) {
      if (g.code == code) return g;
    }
    return null;
  }

  String title(AppLang lang) => switch (this) {
    loseWeight => _pick(lang, 'Vazn tashlash', 'Похудеть', 'Lose weight'),
    energy => _pick(lang, 'Ko‘proq energiya', 'Больше энергии', 'More energy'),
    pressureSugar => _pick(
      lang,
      'Bosim yoki qand nazorati',
      'Контроль давления или сахара',
      'Blood pressure or sugar control',
    ),
    family => _pick(
      lang,
      'Oila salomatligi',
      'Забота о семье',
      'Caring for my family',
    ),
  };

  /// One line under the title: what Sino will do about it.
  String hint(AppLang lang) => switch (this) {
    loseWeight => _pick(
      lang,
      'Kaloriya, mashg‘ulot va vazn kuzatuvi',
      'Калории, тренировки и вес',
      'Calories, workouts and weight',
    ),
    energy => _pick(
      lang,
      'Harakat, nafas mashqi, uyqu va suv',
      'Движение, дыхание, сон и вода',
      'Movement, breathing, sleep and water',
    ),
    pressureSugar => _pick(
      lang,
      'O‘lchovlar, dorilar vaqtida, shifokor',
      'Замеры, лекарства вовремя, врач',
      'Readings, medicines on time, doctor',
    ),
    family => _pick(
      lang,
      'Yaqinlarning dorilari, shifokorlar, dorixona',
      'Лекарства близких, врачи, аптека',
      'Family medicines, doctors, pharmacy',
    ),
  };

  static String _pick(AppLang lang, String uz, String ru, String en) =>
      switch (lang) {
        AppLang.uz => uz,
        AppLang.ru => ru,
        AppLang.en => en,
      };
}
