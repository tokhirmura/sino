import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models.dart';

/// Labels of the reminders feature, uz/ru/en.

/// «Du», «Пн», «Mon» (1 = Monday).
String weekdayShort(BuildContext context, int weekday) => switch (weekday) {
  1 => context.tr(uz: 'Du', ru: 'Пн', en: 'Mon'),
  2 => context.tr(uz: 'Se', ru: 'Вт', en: 'Tue'),
  3 => context.tr(uz: 'Ch', ru: 'Ср', en: 'Wed'),
  4 => context.tr(uz: 'Pa', ru: 'Чт', en: 'Thu'),
  5 => context.tr(uz: 'Ju', ru: 'Пт', en: 'Fri'),
  6 => context.tr(uz: 'Sh', ru: 'Сб', en: 'Sat'),
  _ => context.tr(uz: 'Ya', ru: 'Вс', en: 'Sun'),
};

String weekdayLong(BuildContext context, int weekday) => switch (weekday) {
  1 => context.tr(uz: 'Dushanba', ru: 'Понедельник', en: 'Monday'),
  2 => context.tr(uz: 'Seshanba', ru: 'Вторник', en: 'Tuesday'),
  3 => context.tr(uz: 'Chorshanba', ru: 'Среда', en: 'Wednesday'),
  4 => context.tr(uz: 'Payshanba', ru: 'Четверг', en: 'Thursday'),
  5 => context.tr(uz: 'Juma', ru: 'Пятница', en: 'Friday'),
  6 => context.tr(uz: 'Shanba', ru: 'Суббота', en: 'Saturday'),
  _ => context.tr(uz: 'Yakshanba', ru: 'Воскресенье', en: 'Sunday'),
};

/// «Har kuni», «Ish kunlari», «Dam olish kunlari» or «Du, Ch, Ju».
String daysLabel(BuildContext context, List<int> days) {
  final set = days.toSet();
  if (set.length == 7) {
    return context.tr(uz: 'Har kuni', ru: 'Каждый день', en: 'Every day');
  }
  if (set.length == 5 && set.containsAll(const [1, 2, 3, 4, 5])) {
    return context.tr(uz: 'Ish kunlari', ru: 'По будням', en: 'Weekdays');
  }
  if (set.length == 2 && set.containsAll(const [6, 7])) {
    return context.tr(
      uz: 'Dam olish kunlari',
      ru: 'По выходным',
      en: 'Weekends',
    );
  }
  return [for (final d in days) weekdayShort(context, d)].join(', ');
}

String two(int v) => v.toString().padLeft(2, '0');

/// «08:05».
String hhmm(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

String reminderTime(Reminder r) => '${two(r.hour)}:${two(r.minute)}';

/// «Bugun», «Kecha» or «Seshanba, 17.11».
String dayTitle(BuildContext context, DateTime day, DateTime today) {
  final d = DateTime(day.year, day.month, day.day);
  final diff = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(d).inDays;
  if (diff == 0) return context.tr(uz: 'Bugun', ru: 'Сегодня', en: 'Today');
  if (diff == 1) return context.tr(uz: 'Kecha', ru: 'Вчера', en: 'Yesterday');
  return '${weekdayLong(context, d.weekday)}, ${two(d.day)}.${two(d.month)}';
}

String doseStatusLabel(BuildContext context, DoseStatus s) => switch (s) {
  DoseStatus.taken => context.tr(uz: 'Ichildi', ru: 'Принято', en: 'Taken'),
  DoseStatus.due => context.tr(
    uz: 'Vaqti keldi',
    ru: 'Пора принять',
    en: 'Due now',
  ),
  DoseStatus.upcoming => context.tr(
    uz: 'Kutilmoqda',
    ru: 'Позже',
    en: 'Upcoming',
  ),
  DoseStatus.missed => context.tr(
    uz: 'O‘tkazib yuborildi',
    ru: 'Пропущено',
    en: 'Missed',
  ),
};

Color doseStatusColor(DoseStatus s) => switch (s) {
  DoseStatus.taken => AppColors.good,
  DoseStatus.due => AppColors.amber,
  DoseStatus.upcoming => AppColors.sky,
  DoseStatus.missed => AppColors.danger,
};

IconData doseStatusIcon(DoseStatus s) => switch (s) {
  DoseStatus.taken => Icons.check_circle_rounded,
  DoseStatus.due => Icons.notifications_active_rounded,
  DoseStatus.upcoming => Icons.schedule_rounded,
  DoseStatus.missed => Icons.error_outline_rounded,
};
