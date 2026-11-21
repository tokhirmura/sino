import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import 'sino_index.dart';

/// Part of the day for the greeting.
enum DayPart {
  /// 05:00–10:59 — «Xayrli tong».
  morning,

  /// 11:00–16:59 — «Xayrli kun».
  day,

  /// 17:00–04:59 — «Xayrli kech».
  evening;

  static DayPart of(DateTime t) => t.hour >= 5 && t.hour < 11
      ? morning
      : t.hour >= 11 && t.hour < 17
      ? day
      : evening;
}

/// «Xayrli tong, Aziz» / «Доброе утро, Aziz» / «Good morning, Aziz».
String greeting(AppLang lang, DayPart part, String name) {
  final hello = switch ((lang, part)) {
    (AppLang.uz, DayPart.morning) => 'Xayrli tong',
    (AppLang.uz, DayPart.day) => 'Xayrli kun',
    (AppLang.uz, DayPart.evening) => 'Xayrli kech',
    (AppLang.ru, DayPart.morning) => 'Доброе утро',
    (AppLang.ru, DayPart.day) => 'Добрый день',
    (AppLang.ru, DayPart.evening) => 'Добрый вечер',
    (AppLang.en, DayPart.morning) => 'Good morning',
    (AppLang.en, DayPart.day) => 'Good afternoon',
    (AppLang.en, DayPart.evening) => 'Good evening',
  };
  return name.isEmpty ? hello : '$hello, $name';
}

/// 1240 → «1 240».
String groupThousands(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// Live one-line summary of today:
/// «Bugun 1 240 kkal, 5 stakan suv, dorilar vaqtida ✓».
/// Only what was logged; `null` when nothing is.
String? todaySummary(AppLang lang, SinoDay today, DateTime now) {
  final i = today.input;
  final parts = <String>[];
  if (i.kcal != null) {
    parts.add(
      '${groupThousands(i.kcal!)} '
      '${switch (lang) {
        AppLang.uz => 'kkal',
        AppLang.ru => 'ккал',
        AppLang.en => 'kcal',
      }}',
    );
  }
  if (i.glasses != null) {
    parts.add(switch (lang) {
      AppLang.uz => '${i.glasses} stakan suv',
      AppLang.ru => '${i.glasses} ${_glassesRu(i.glasses!)} воды',
      AppLang.en =>
        '${i.glasses} ${i.glasses == 1 ? 'glass' : 'glasses'} of water',
    });
  }
  final due = i.doses.where((d) => d.taken || !d.at.isAfter(now)).toList();
  if (due.isNotEmpty) {
    final missed = due.where((d) => !d.taken).length;
    parts.add(
      missed == 0
          ? switch (lang) {
              AppLang.uz => 'dorilar vaqtida\u00A0✓',
              AppLang.ru => 'лекарства вовремя\u00A0✓',
              AppLang.en => 'medicines on time\u00A0✓',
            }
          : switch (lang) {
              AppLang.uz => '$missed ta dori ichilmagan',
              AppLang.ru => 'не принято лекарств: $missed',
              AppLang.en => '$missed ${missed == 1 ? 'dose' : 'doses'} missed',
            },
    );
  }
  if (i.workouts > 0) {
    parts.add(switch (lang) {
      AppLang.uz => 'mashg‘ulot\u00A0✓',
      AppLang.ru => 'тренировка\u00A0✓',
      AppLang.en => 'workout\u00A0✓',
    });
  } else if (i.steps != null) {
    parts.add(switch (lang) {
      AppLang.uz => '${groupThousands(i.steps!)} qadam',
      AppLang.ru => '${groupThousands(i.steps!)} шагов',
      AppLang.en => '${groupThousands(i.steps!)} steps',
    });
  }
  if (parts.isEmpty) return null;
  final head = switch (lang) {
    AppLang.uz => 'Bugun',
    AppLang.ru => 'Сегодня',
    AppLang.en => 'Today',
  };
  return '$head ${parts.join(', ')}';
}

String _glassesRu(int n) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'стакан';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'стакана';
  return 'стаканов';
}

/// Grade of an index for colors and labels.
enum SinoLevel {
  /// 80–100
  great,

  /// 60–79 (keeps the streak)
  good,

  /// 40–59
  fair,

  /// 0–39
  low;

  static SinoLevel of(int score) => score >= 80
      ? great
      : score >= sinoStreakThreshold
      ? good
      : score >= 40
      ? fair
      : low;
}

/// A proverb / saying of the day: Uzbek original + translations.
class DailyQuote {
  const DailyQuote({required this.uz, required this.ru, required this.en});

  factory DailyQuote.fromJson(Map<String, dynamic> m) => DailyQuote(
    uz: m['uz'] as String,
    ru: m['ru'] as String,
    en: m['en'] as String,
  );

  final String uz;
  final String ru;
  final String en;

  /// Translation for a non-Uzbek UI; `null` for Uzbek.
  String? translation(AppLang lang) => switch (lang) {
    AppLang.uz => null,
    AppLang.ru => ru,
    AppLang.en => en,
  };
}

/// Same quote all day, a new one every day (day of year).
int quoteIndexFor(DateTime day, int count) {
  final dayOfYear = day.difference(DateTime(day.year)).inDays;
  return dayOfYear % count;
}

/// All quotes from `assets/core/quotes.json` (bundled, works offline).
final quotesProvider = FutureProvider<List<DailyQuote>>((ref) async {
  final json = jsonDecode(
    await rootBundle.loadString('assets/core/quotes.json', cache: false),
  ) as Map<String, dynamic>;
  return [
    for (final q in json['quotes'] as List)
      DailyQuote.fromJson(q as Map<String, dynamic>),
  ];
});

/// Today's quote.
final quoteOfTheDayProvider = FutureProvider<DailyQuote>((ref) async {
  final quotes = await ref.watch(quotesProvider.future);
  final now = ref.watch(sinoClockProvider)();
  return quotes[quoteIndexFor(now, quotes.length)];
});
