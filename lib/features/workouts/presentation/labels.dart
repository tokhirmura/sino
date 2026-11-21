import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_lang.dart';
import '../application/plan_generator.dart';
import '../data/models.dart';

extension WorkoutTypeLabel on WorkoutType {
  String get emoji => switch (this) {
    WorkoutType.home => '🏠',
    WorkoutType.gym => '🏋️',
    WorkoutType.run => '🏃',
    WorkoutType.yoga => '🧘',
    WorkoutType.swim => '🏊',
    WorkoutType.kurash => '🤼',
  };

  String label(BuildContext context) => switch (this) {
    WorkoutType.home => context.tr(uz: 'Uyda', ru: 'Дома', en: 'Home'),
    WorkoutType.gym => context.tr(uz: 'Zal', ru: 'Зал', en: 'Gym'),
    WorkoutType.run => context.tr(uz: 'Yugurish', ru: 'Бег', en: 'Running'),
    WorkoutType.yoga => context.tr(uz: 'Yoga', ru: 'Йога', en: 'Yoga'),
    WorkoutType.swim => context.tr(
      uz: 'Suzish',
      ru: 'Плавание',
      en: 'Swimming',
    ),
    WorkoutType.kurash => context.tr(
      uz: 'Kurash (O‘FP)',
      ru: 'Кураш (ОФП)',
      en: 'Kurash (GPP)',
    ),
  };
}

extension WorkoutGoalLabel on WorkoutGoal {
  String get emoji => switch (this) {
    WorkoutGoal.lose => '🔥',
    WorkoutGoal.gain => '💪',
    WorkoutGoal.endurance => '🫀',
    WorkoutGoal.flexibility => '🤸',
  };

  String label(BuildContext context) => switch (this) {
    WorkoutGoal.lose => context.tr(
      uz: 'Ozish',
      ru: 'Похудение',
      en: 'Lose weight',
    ),
    WorkoutGoal.gain => context.tr(
      uz: 'Massa',
      ru: 'Масса',
      en: 'Build muscle',
    ),
    WorkoutGoal.endurance => context.tr(
      uz: 'Chidamlilik',
      ru: 'Выносливость',
      en: 'Endurance',
    ),
    WorkoutGoal.flexibility => context.tr(
      uz: 'Egiluvchanlik',
      ru: 'Гибкость',
      en: 'Flexibility',
    ),
  };
}

extension WorkoutLevelLabel on WorkoutLevel {
  String label(BuildContext context) => switch (this) {
    WorkoutLevel.beginner => context.tr(
      uz: 'Boshlang‘ich',
      ru: 'Новичок',
      en: 'Beginner',
    ),
    WorkoutLevel.intermediate => context.tr(
      uz: 'O‘rta',
      ru: 'Средний',
      en: 'Intermediate',
    ),
    WorkoutLevel.advanced => context.tr(
      uz: 'Yuqori',
      ru: 'Продвинутый',
      en: 'Advanced',
    ),
  };
}

/// 1 = Monday … 7 = Sunday.
String weekdayName(BuildContext context, int weekday) {
  const uz = [
    'Dushanba',
    'Seshanba',
    'Chorshanba',
    'Payshanba',
    'Juma',
    'Shanba',
    'Yakshanba',
  ];
  const ru = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];
  const en = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final i = (weekday - 1).clamp(0, 6);
  return context.tr(uz: uz[i], ru: ru[i], en: en[i]);
}

/// Bad-air warning (AQI > 100), the same words as on the weather screen:
/// «Havo ifloslangan (AQI 156) — bugun uyda mashq qiling». [place] is
/// appended inside the brackets as given (e.g. `, Toshkent`).
String airAlertText(BuildContext context, int aqi, {String place = ''}) =>
    context.tr(
      uz: 'Havo ifloslangan (AQI $aqi$place) — bugun uyda mashq qiling',
      ru: 'Воздух загрязнён (AQI $aqi$place) — сегодня тренируйтесь дома',
      en: 'The air is polluted (AQI $aqi$place) — work out at home today',
    );

String minUnit(BuildContext context) =>
    context.tr(uz: 'daq', ru: 'мин', en: 'min');

String kcalUnit(BuildContext context) =>
    context.tr(uz: 'kkal', ru: 'ккал', en: 'kcal');

/// «3 × 12», «3 × 45 s», «12 daq».
String doseText(BuildContext context, PlanItem item) {
  final s = item.seconds;
  if (item.reps != null) return '${item.sets} × ${item.reps}';
  if (s == null) return '${item.sets}×';
  final time = s >= 120 && s % 60 == 0
      ? '${s ~/ 60} ${minUnit(context)}'
      : '$s ${context.tr(uz: 's', ru: 'с', en: 's')}';
  return item.sets == 1 ? time : '${item.sets} × $time';
}

String muscleEmoji(String? muscle) => switch (muscle) {
  'legs' || 'glutes' => '🦵',
  'cardio' => '❤️',
  'core' => '🧱',
  'chest' || 'shoulders' || 'arms' => '💪',
  // Not 🔙 — it renders as an arrow with the English word «BACK».
  'back' => '🧗',
  _ => '🏅',
};
