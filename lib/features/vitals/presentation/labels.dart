import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../application/vitals_math.dart';
import '../data/models.dart';

extension VitalKindLabel on VitalKind {
  String get emoji => switch (this) {
    VitalKind.pulse => '❤️',
    VitalKind.steps => '👣',
    VitalKind.sleep => '😴',
    VitalKind.weight => '⚖️',
    VitalKind.pressure => '🩺',
    VitalKind.glucose => '🩸',
  };

  Color get color => switch (this) {
    VitalKind.pulse => AppColors.coral,
    VitalKind.steps => AppColors.good,
    VitalKind.sleep => AppColors.violet,
    VitalKind.weight => AppColors.amber,
    VitalKind.pressure => AppColors.sky,
    VitalKind.glucose => AppColors.danger,
  };

  String label(BuildContext context) => switch (this) {
    VitalKind.pulse => context.tr(uz: 'Puls', ru: 'Пульс', en: 'Pulse'),
    VitalKind.steps => context.tr(uz: 'Qadamlar', ru: 'Шаги', en: 'Steps'),
    VitalKind.sleep => context.tr(uz: 'Uyqu', ru: 'Сон', en: 'Sleep'),
    VitalKind.weight => context.tr(uz: 'Vazn', ru: 'Вес', en: 'Weight'),
    VitalKind.pressure => context.tr(
      uz: 'Qon bosimi',
      ru: 'Давление',
      en: 'Blood pressure',
    ),
    VitalKind.glucose => context.tr(
      uz: 'Qonda qand',
      ru: 'Сахар в крови',
      en: 'Blood glucose',
    ),
  };

  String unitText(BuildContext context) => switch (this) {
    VitalKind.pulse => context.tr(uz: 'zarba/daq', ru: 'уд/мин', en: 'bpm'),
    VitalKind.steps => context.tr(uz: 'qadam', ru: 'шагов', en: 'steps'),
    VitalKind.sleep => context.tr(uz: 'soat', ru: 'ч', en: 'h'),
    VitalKind.weight => context.tr(uz: 'kg', ru: 'кг', en: 'kg'),
    VitalKind.pressure => context.tr(
      uz: 'mm sim. ust.',
      ru: 'мм рт. ст.',
      en: 'mmHg',
    ),
    VitalKind.glucose => context.tr(uz: 'mmol/l', ru: 'ммоль/л', en: 'mmol/L'),
  };

  /// General reference range, e.g. «60–100».
  String? normText() {
    String f(double v) => formatNumber(this, v);
    final lo = low, hi = high;
    if (this == VitalKind.pressure) {
      return '${f(lo!)}–${f(hi!)} / ${f(low2!)}–${f(high2!)}';
    }
    if (lo != null && hi != null) return '${f(lo)}–${f(hi)}';
    if (lo != null) return '≥ ${f(lo)}';
    return null;
  }

  /// Decimals in the input field.
  bool get decimal =>
      this == VitalKind.sleep ||
      this == VitalKind.weight ||
      this == VitalKind.glucose;
}

/// «7 500», «7.2», «118».
String formatNumber(VitalKind k, double v) {
  if (k.decimal) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
  final n = v.round().toString();
  if (n.length <= 4) return n;
  final b = StringBuffer();
  for (var i = 0; i < n.length; i++) {
    if (i > 0 && (n.length - i) % 3 == 0) b.write(' ');
    b.write(n[i]);
  }
  return b.toString();
}

/// «118/76» for pressure, else the number.
String vitalValueText(Vital v) => v.kind == VitalKind.pressure
    ? '${v.value.round()}/${(v.value2 ?? 0).round()}'
    : formatNumber(v.kind, v.value);

Color statusColor(VitalStatus s) => switch (s) {
  VitalStatus.low => AppColors.sky,
  VitalStatus.normal => AppColors.good,
  VitalStatus.high => AppColors.danger,
};

String statusText(BuildContext context, VitalKind k, VitalStatus s) =>
    switch (s) {
      VitalStatus.normal => context.tr(
        uz: 'Me’yorda',
        ru: 'В норме',
        en: 'Normal',
      ),
      VitalStatus.low =>
        k == VitalKind.steps
            ? context.tr(uz: 'Kam', ru: 'Мало', en: 'Few')
            : context.tr(uz: 'Past', ru: 'Низкий', en: 'Low'),
      VitalStatus.high => context.tr(uz: 'Yuqori', ru: 'Высокий', en: 'High'),
    };

({String text, Color color}) bmiText(BuildContext context, BmiLevel l) =>
    switch (l) {
      BmiLevel.under => (
        text: context.tr(
          uz: 'Vazn yetishmaydi',
          ru: 'Недостаточный вес',
          en: 'Underweight',
        ),
        color: AppColors.sky,
      ),
      BmiLevel.normal => (
        text: context.tr(uz: 'Me’yorda', ru: 'Норма', en: 'Normal'),
        color: AppColors.good,
      ),
      BmiLevel.over => (
        text: context.tr(
          uz: 'Ortiqcha vazn',
          ru: 'Избыточный вес',
          en: 'Overweight',
        ),
        color: AppColors.amber,
      ),
      BmiLevel.obese => (
        text: context.tr(uz: 'Semizlik', ru: 'Ожирение', en: 'Obesity'),
        color: AppColors.danger,
      ),
    };

/// Short weekday (1 = Monday).
String weekdayShort(BuildContext context, int weekday) {
  const uz = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  const ru = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  const en = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  final i = (weekday - 1).clamp(0, 6);
  return context.tr(uz: uz[i], ru: ru[i], en: en[i]);
}

/// «Bugun 08:30», «Kecha 21:10», «15.11 08:30».
String whenText(BuildContext context, DateTime t, DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(t.hour)}:${two(t.minute)}';
  final d = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(d).inDays;
  if (days == 0) {
    return '${context.tr(uz: 'Bugun', ru: 'Сегодня', en: 'Today')} $time';
  }
  if (days == 1) {
    return '${context.tr(uz: 'Kecha', ru: 'Вчера', en: 'Yesterday')} $time';
  }
  return '${two(t.day)}.${two(t.month)} $time';
}
