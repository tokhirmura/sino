import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models.dart';

/// Labels of the pharmacy slugs (`form`, `category`, statuses), uz/ru/en.

String formLabel(BuildContext context, String? form) => switch (form) {
  'tablet' => context.tr(uz: 'Tabletka', ru: 'Таблетки', en: 'Tablets'),
  'capsule' => context.tr(uz: 'Kapsula', ru: 'Капсулы', en: 'Capsules'),
  'syrup' => context.tr(uz: 'Sirop', ru: 'Сироп', en: 'Syrup'),
  'powder' => context.tr(uz: 'Kukun', ru: 'Порошок', en: 'Powder'),
  'spray' => context.tr(uz: 'Sprey', ru: 'Спрей', en: 'Spray'),
  'drops' => context.tr(uz: 'Tomchi', ru: 'Капли', en: 'Drops'),
  'ointment' => context.tr(uz: 'Malham', ru: 'Мазь', en: 'Ointment'),
  _ => form ?? '',
};

String categoryLabel(BuildContext context, String? category) =>
    switch (category) {
      'pain' => context.tr(
        uz: 'Og‘riq va isitma',
        ru: 'Боль и температура',
        en: 'Pain and fever',
      ),
      'cold' => context.tr(
        uz: 'Shamollash va yo‘tal',
        ru: 'Простуда и кашель',
        en: 'Cold and cough',
      ),
      'allergy' => context.tr(uz: 'Allergiya', ru: 'Аллергия', en: 'Allergy'),
      'stomach' => context.tr(
        uz: 'Oshqozon va ichak',
        ru: 'Желудок и кишечник',
        en: 'Stomach and gut',
      ),
      'heart' => context.tr(
        uz: 'Yurak va bosim',
        ru: 'Сердце и давление',
        en: 'Heart and blood pressure',
      ),
      'diabetes' => context.tr(uz: 'Diabet', ru: 'Диабет', en: 'Diabetes'),
      'antibiotic' => context.tr(
        uz: 'Antibiotiklar',
        ru: 'Антибиотики',
        en: 'Antibiotics',
      ),
      'vitamins' => context.tr(
        uz: 'Vitaminlar',
        ru: 'Витамины',
        en: 'Vitamins',
      ),
      'skin' => context.tr(uz: 'Teri', ru: 'Кожа', en: 'Skin'),
      'eye' => context.tr(uz: 'Ko‘z', ru: 'Глаза', en: 'Eyes'),
      'nerves' => context.tr(
        uz: 'Asab va uyqu',
        ru: 'Нервы и сон',
        en: 'Nerves and sleep',
      ),
      _ => category ?? '',
    };

String categoryEmoji(String? category) => switch (category) {
  'pain' => '🌡️',
  'cold' => '🤧',
  'allergy' => '🌼',
  'stomach' => '🍵',
  'heart' => '❤️',
  'diabetes' => '🩸',
  'antibiotic' => '🦠',
  'vitamins' => '🍊',
  'skin' => '🩹',
  'eye' => '👁️',
  'nerves' => '😌',
  _ => '💊',
};

Color categoryColor(String? category) => switch (category) {
  'pain' || 'heart' => AppColors.coral,
  'cold' || 'eye' => AppColors.sky,
  'allergy' || 'vitamins' => AppColors.amber,
  'nerves' || 'antibiotic' => AppColors.violet,
  _ => AppColors.primary,
};

String statusLabel(BuildContext context, ReservationStatus s) => switch (s) {
  ReservationStatus.pending => context.tr(
    uz: 'Tayyorlanmoqda',
    ru: 'Собирается',
    en: 'Being prepared',
  ),
  ReservationStatus.ready => context.tr(
    uz: 'Olib ketishga tayyor',
    ru: 'Готово к выдаче',
    en: 'Ready for pickup',
  ),
  ReservationStatus.picked => context.tr(
    uz: 'Olib ketilgan',
    ru: 'Получено',
    en: 'Picked up',
  ),
  ReservationStatus.cancelled => context.tr(
    uz: 'Bekor qilingan',
    ru: 'Отменено',
    en: 'Cancelled',
  ),
};

Color statusColor(ReservationStatus s) => switch (s) {
  ReservationStatus.pending => AppColors.amber,
  ReservationStatus.ready => AppColors.good,
  ReservationStatus.picked => AppColors.sky,
  ReservationStatus.cancelled => AppColors.danger,
};

IconData statusIcon(ReservationStatus s) => switch (s) {
  ReservationStatus.pending => Icons.hourglass_top_rounded,
  ReservationStatus.ready => Icons.check_circle_rounded,
  ReservationStatus.picked => Icons.shopping_bag_rounded,
  ReservationStatus.cancelled => Icons.cancel_rounded,
};

/// 0.85 → «850 m», 3.24 → «3.2 km».
String formatDistance(BuildContext context, double km) {
  if (km < 1) {
    final m = (km * 1000 / 10).round() * 10;
    return '$m ${context.tr(uz: 'm', ru: 'м', en: 'm')}';
  }
  final v = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
  return '$v ${context.tr(uz: 'km', ru: 'км', en: 'km')}';
}

/// «17.11 · 14:05».
String formatDateTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)} · ${two(t.hour)}:${two(t.minute)}';
}

/// «24/7» or the free-text hours.
String hoursLabel(BuildContext context, Pharmacy p) => p.open24
    ? context.tr(uz: 'Kecha-kunduz', ru: 'Круглосуточно', en: 'Open 24/7')
    : (p.hours ?? '');
