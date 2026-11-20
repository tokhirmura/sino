import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models.dart';

/// Labels of the doctors feature, uz/ru/en. Specialty slugs: see
/// `doctorSpecialties`; an unknown slug is shown as is.

String specialtyLabel(BuildContext context, String slug) => switch (slug) {
  'terapevt' => context.tr(
    uz: 'Terapevt',
    ru: 'Терапевт',
    en: 'General practitioner',
  ),
  'pediatr' => context.tr(uz: 'Pediatr', ru: 'Педиатр', en: 'Pediatrician'),
  'kardiolog' => context.tr(
    uz: 'Kardiolog',
    ru: 'Кардиолог',
    en: 'Cardiologist',
  ),
  'nevrolog' => context.tr(uz: 'Nevrolog', ru: 'Невролог', en: 'Neurologist'),
  'dermatolog' => context.tr(
    uz: 'Dermatolog',
    ru: 'Дерматолог',
    en: 'Dermatologist',
  ),
  'ginekolog' => context.tr(
    uz: 'Ginekolog',
    ru: 'Гинеколог',
    en: 'Gynecologist',
  ),
  'lor' => context.tr(uz: 'LOR', ru: 'ЛОР', en: 'ENT specialist'),
  'oftalmolog' => context.tr(
    uz: 'Oftalmolog',
    ru: 'Офтальмолог',
    en: 'Ophthalmologist',
  ),
  'stomatolog' => context.tr(uz: 'Stomatolog', ru: 'Стоматолог', en: 'Dentist'),
  'endokrinolog' => context.tr(
    uz: 'Endokrinolog',
    ru: 'Эндокринолог',
    en: 'Endocrinologist',
  ),
  'gastroenterolog' => context.tr(
    uz: 'Gastroenterolog',
    ru: 'Гастроэнтеролог',
    en: 'Gastroenterologist',
  ),
  'psixolog' => context.tr(uz: 'Psixolog', ru: 'Психолог', en: 'Psychologist'),
  _ => slug,
};

String specialtyEmoji(String slug) => switch (slug) {
  'terapevt' => '🩺',
  'pediatr' => '🧸',
  'kardiolog' => '❤️',
  'nevrolog' => '🧠',
  'dermatolog' => '🧴',
  'ginekolog' => '🌸',
  'lor' => '👂',
  'oftalmolog' => '👁️',
  'stomatolog' => '🦷',
  'endokrinolog' => '🧪',
  'gastroenterolog' => '🍽️',
  'psixolog' => '💬',
  _ => '👨‍⚕️',
};

Color specialtyColor(String slug) => switch (slug) {
  'kardiolog' => AppColors.coral,
  'pediatr' || 'ginekolog' => AppColors.violet,
  'nevrolog' || 'psixolog' => AppColors.sky,
  'stomatolog' || 'oftalmolog' || 'lor' => AppColors.amber,
  _ => AppColors.primary,
};

String appointmentStatusLabel(
  BuildContext context,
  Appointment a,
  DateTime now,
) {
  if (a.status == AppointmentStatus.cancelled) {
    return context.tr(uz: 'Bekor qilingan', ru: 'Отменена', en: 'Cancelled');
  }
  if (a.status == AppointmentStatus.done) {
    return context.tr(uz: 'Bo‘lib o‘tdi', ru: 'Состоялась', en: 'Completed');
  }
  if (a.isPast(now)) {
    return context.tr(uz: 'Vaqti o‘tdi', ru: 'Прошла', en: 'Past');
  }
  return context.tr(uz: 'Yozilgan', ru: 'Запись', en: 'Booked');
}

Color appointmentStatusColor(Appointment a, DateTime now) {
  if (a.status == AppointmentStatus.cancelled) return AppColors.danger;
  if (a.status == AppointmentStatus.done) return AppColors.good;
  if (a.isPast(now)) return AppColors.amber;
  return AppColors.primary;
}

String _two(int v) => v.toString().padLeft(2, '0');

String hhmm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

String weekdayShort(BuildContext context, int weekday) => switch (weekday) {
  1 => context.tr(uz: 'Du', ru: 'Пн', en: 'Mon'),
  2 => context.tr(uz: 'Se', ru: 'Вт', en: 'Tue'),
  3 => context.tr(uz: 'Ch', ru: 'Ср', en: 'Wed'),
  4 => context.tr(uz: 'Pa', ru: 'Чт', en: 'Thu'),
  5 => context.tr(uz: 'Ju', ru: 'Пт', en: 'Fri'),
  6 => context.tr(uz: 'Sh', ru: 'Сб', en: 'Sat'),
  _ => context.tr(uz: 'Ya', ru: 'Вс', en: 'Sun'),
};

/// «Bugun», «Ertaga» or «Ju, 20.11».
String dayLabel(BuildContext context, DateTime day, DateTime now) {
  final d = DateTime(day.year, day.month, day.day);
  final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (diff == 0) return context.tr(uz: 'Bugun', ru: 'Сегодня', en: 'Today');
  if (diff == 1) return context.tr(uz: 'Ertaga', ru: 'Завтра', en: 'Tomorrow');
  if (diff == -1) return context.tr(uz: 'Kecha', ru: 'Вчера', en: 'Yesterday');
  return '${weekdayShort(context, d.weekday)}, ${_two(d.day)}.${_two(d.month)}';
}

/// «Ertaga · 10:30».
String appointmentWhen(BuildContext context, DateTime at, DateTime now) =>
    '${dayLabel(context, at, now)} · ${hhmm(at)}';

String yearsLabel(BuildContext context, int years) => context.tr(
  uz: '$years yil tajriba',
  ru: 'Стаж $years лет',
  en: '$years years’ experience',
);
