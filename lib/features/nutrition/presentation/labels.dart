import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../data/dasturxon.dart';
import '../data/models.dart';

extension MealLabel on Meal {
  String label(BuildContext context) => switch (this) {
    Meal.breakfast => context.tr(
      uz: 'Nonushta',
      ru: 'Завтрак',
      en: 'Breakfast',
    ),
    Meal.lunch => context.tr(uz: 'Tushlik', ru: 'Обед', en: 'Lunch'),
    Meal.dinner => context.tr(uz: 'Kechki ovqat', ru: 'Ужин', en: 'Dinner'),
    Meal.snack => context.tr(uz: 'Gazak', ru: 'Перекус', en: 'Snack'),
  };

  String get emoji => switch (this) {
    Meal.breakfast => '🍳',
    Meal.lunch => '🍲',
    Meal.dinner => '🍽️',
    Meal.snack => '🍎',
  };

  Color get color => switch (this) {
    Meal.breakfast => AppColors.amber,
    Meal.lunch => AppColors.primary,
    Meal.dinner => AppColors.violet,
    Meal.snack => AppColors.coral,
  };

  /// Meal that fits the clock — preselected in the «add food» sheet.
  static Meal forHour(int hour) => switch (hour) {
    >= 5 && < 11 => Meal.breakfast,
    >= 11 && < 16 => Meal.lunch,
    >= 18 && < 23 => Meal.dinner,
    _ => Meal.snack,
  };
}

/// 1 → «1», 1.5 → «1.5», 0.25 → «0.25» (home measures give quarters).
String formatServings(double v) => v == v.roundToDouble()
    ? v.toInt().toString()
    : (v * 10) == (v * 10).roundToDouble()
    ? v.toStringAsFixed(1)
    : v.toStringAsFixed(2);

/// 0.5 → «½», 1.5 → «1½», 2 → «2».
String countText(double c) {
  final whole = c.floor();
  final half = c - whole >= 0.5;
  if (!half) return '$whole';
  return whole == 0 ? '½' : '$whole½';
}

/// «1 kosa», «½ likopcha», «2 dona»; Russian and English agree in number:
/// «2 миски», «½ тарелки», «2 bowls».
String measureText(BuildContext context, HomeMeasure m, double count) {
  final n = countText(count);
  final one = count == 1;
  return switch (context.lang) {
    AppLang.uz =>
      '$n ${switch (m) {
        HomeMeasure.kosa => 'kosa',
        HomeMeasure.likopcha => 'likopcha',
        HomeMeasure.dona => 'dona',
        HomeMeasure.piyola => 'piyola',
        HomeMeasure.choyQoshiq => 'choy qoshiq',
      }}',
    // 1 → nominative; ½, 1½, 2–4 → genitive singular (all presets ≤ 4).
    AppLang.ru =>
      '$n ${switch (m) {
        HomeMeasure.kosa => one ? 'миска' : 'миски',
        HomeMeasure.likopcha => one ? 'тарелка' : 'тарелки',
        HomeMeasure.dona => 'шт.',
        HomeMeasure.piyola => one ? 'пиала' : 'пиалы',
        HomeMeasure.choyQoshiq => 'ч. л.',
      }}',
    AppLang.en =>
      '$n ${switch (m) {
        HomeMeasure.kosa => count <= 1 ? 'bowl' : 'bowls',
        HomeMeasure.likopcha => count <= 1 ? 'plate' : 'plates',
        HomeMeasure.dona => count <= 1 ? 'piece' : 'pieces',
        HomeMeasure.piyola => count <= 1 ? 'cup' : 'cups',
        HomeMeasure.choyQoshiq => 'tsp',
      }}',
  };
}

/// «Bugun», «Kecha» or «Pn, 12.11» (year shown if not the current one).
String dayLabel(BuildContext context, DateTime day, DateTime today) {
  // UTC dates: a local day can be 23 h long across a DST change.
  final diff = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
  if (diff == 0) return context.tr(uz: 'Bugun', ru: 'Сегодня', en: 'Today');
  if (diff == 1) return context.tr(uz: 'Kecha', ru: 'Вчера', en: 'Yesterday');
  final week = switch (context.lang) {
    AppLang.uz => const ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'],
    AppLang.ru => const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
    AppLang.en => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  };
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${two(day.day)}.${two(day.month)}';
  final year = day.year == today.year ? '' : '.${day.year}';
  return '${week[day.weekday - 1]}, $date$year';
}

String kcalUnit(BuildContext context) =>
    context.tr(uz: 'kkal', ru: 'ккал', en: 'kcal');

String gramUnit(BuildContext context) => context.tr(uz: 'g', ru: 'г', en: 'g');

/// Small mark of where a custom food came from (`null` for the catalog).
String? sourceBadge(FoodSource s) => switch (s) {
  FoodSource.catalog => null,
  FoodSource.photo => '📷',
  FoodSource.recipe => '🍳',
  FoodSource.barcode => '🏷️',
  FoodSource.quick => '⚡',
};
