import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../data/medical_repository.dart';

/// Blood types offered in forms (stored as text, e.g. «A(II) Rh+»).
const bloodTypes = [
  'O(I) Rh+',
  'O(I) Rh-',
  'A(II) Rh+',
  'A(II) Rh-',
  'B(III) Rh+',
  'B(III) Rh-',
  'AB(IV) Rh+',
  'AB(IV) Rh-',
];

/// `family_members.relation` is stored in Uzbek; these are the choices.
const relations = [
  'ona',
  'ota',
  'turmush o‘rtog‘i',
  'o‘g‘li',
  'qizi',
  'aka-uka',
  'opa-singil',
  'buvi',
  'bobo',
  'boshqa',
];

String relationLabel(BuildContext c, String key) => switch (key) {
  'ona' => c.tr(uz: 'Ona', ru: 'Мама', en: 'Mother'),
  'ota' => c.tr(uz: 'Ota', ru: 'Папа', en: 'Father'),
  'turmush o‘rtog‘i' => c.tr(
    uz: 'Turmush o‘rtog‘i',
    ru: 'Супруг(а)',
    en: 'Spouse',
  ),
  'o‘g‘li' => c.tr(uz: 'O‘g‘li', ru: 'Сын', en: 'Son'),
  'qizi' => c.tr(uz: 'Qizi', ru: 'Дочь', en: 'Daughter'),
  'aka-uka' => c.tr(uz: 'Aka-uka', ru: 'Брат', en: 'Brother'),
  'opa-singil' => c.tr(uz: 'Opa-singil', ru: 'Сестра', en: 'Sister'),
  'buvi' => c.tr(uz: 'Buvi', ru: 'Бабушка', en: 'Grandmother'),
  'bobo' => c.tr(uz: 'Bobo', ru: 'Дедушка', en: 'Grandfather'),
  'boshqa' => c.tr(uz: 'Boshqa', ru: 'Другое', en: 'Other'),
  _ => key,
};

String relationEmoji(String key) => switch (key) {
  'ona' || 'buvi' => '👩',
  'ota' || 'bobo' => '👨',
  'qizi' || 'opa-singil' => '👧',
  'o‘g‘li' || 'aka-uka' => '👦',
  'turmush o‘rtog‘i' => '💞',
  _ => '🧑',
};

String recordEmoji(String kind) => switch (kind) {
  'visit' => '🩺',
  'lab' => '🧪',
  'prescription' => '💊',
  'vaccine' => '💉',
  'diagnosis' => '📋',
  _ => '📄',
};

String recordKindLabel(BuildContext c, String kind) => switch (kind) {
  'visit' => c.tr(uz: 'Ko‘rik', ru: 'Приём', en: 'Visit'),
  'lab' => c.tr(uz: 'Tahlil', ru: 'Анализ', en: 'Lab test'),
  'prescription' => c.tr(uz: 'Retsept', ru: 'Рецепт', en: 'Prescription'),
  'vaccine' => c.tr(uz: 'Emlash', ru: 'Прививка', en: 'Vaccine'),
  'diagnosis' => c.tr(uz: 'Tashxis', ru: 'Диагноз', en: 'Diagnosis'),
  _ => kind,
};

String sourceLabel(BuildContext c, RecordSource s) => switch (s) {
  RecordSource.davlat => c.tr(uz: 'Davlat', ru: 'Гос.', en: 'State'),
  RecordSource.xususiy => c.tr(uz: 'Xususiy', ru: 'Частная', en: 'Private'),
};

Color sourceColor(RecordSource s) =>
    s == RecordSource.davlat ? AppColors.sky : AppColors.violet;

Color labColor(LabStatus s) => switch (s) {
  LabStatus.normal => AppColors.good,
  LabStatus.low => AppColors.amber,
  LabStatus.high => AppColors.coral,
};

String labStatusLabel(BuildContext c, LabStatus s) => switch (s) {
  LabStatus.normal => c.tr(uz: 'Me’yorda', ru: 'В норме', en: 'Normal'),
  LabStatus.low => c.tr(uz: 'Past', ru: 'Ниже нормы', en: 'Low'),
  LabStatus.high => c.tr(uz: 'Yuqori', ru: 'Выше нормы', en: 'High'),
};

/// «12.11.2026» style date in the current locale's order.
String shortDate(BuildContext c, DateTime d) =>
    MaterialLocalizations.of(c).formatCompactDate(d);

/// «42» / «5.4».
String formatNum(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
