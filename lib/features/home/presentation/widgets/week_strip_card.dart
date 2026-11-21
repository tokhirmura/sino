import 'package:flutter/material.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../application/home_today.dart';
import '../../application/sino_index.dart';
import 'sino_index_card.dart' show levelColor;

/// Mon…Sun short names (weekday 1…7).
String weekdayShort(AppLang lang, int weekday) => switch (lang) {
  AppLang.uz => const ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'],
  AppLang.ru => const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
  AppLang.en => const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
}[weekday - 1];

/// Streak of days with index ≥ 60 and the last 7 days as colored dots.
class WeekStripCard extends StatelessWidget {
  const WeekStripCard({
    super.key,
    required this.week,
    required this.streak,
    required this.lang,
  });

  /// Oldest first, today last.
  final List<SinoDay> week;
  final int streak;
  final AppLang lang;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      key: const ValueKey('week-strip'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                streak > 0 ? '🔥' : '🌱',
                style: const TextStyle(fontSize: 22, height: 1.1),
                textScaler: TextScaler.noScaling,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  streak > 0
                      ? context.tr(
                          uz: '$streak kun ketma-ket',
                          ru: 'Серия: $streak ${_daysRu(streak)}',
                          en: '$streak-day streak',
                        )
                      : context.tr(
                          uz: 'Seriyani bugun boshlang',
                          ru: 'Начните серию сегодня',
                          en: 'Start a streak today',
                        ),
                  key: const ValueKey('streak'),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                context.tr(uz: '7 kun', ru: '7 дней', en: '7 days'),
                style: text.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              uz: 'Indeks 60 va undan yuqori bo‘lgan kunlar',
              ru: 'Дни с индексом от 60',
              en: 'Days with an index of 60+',
            ),
            style: text.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < week.length; i++)
                _Dot(
                  day: week[i],
                  label: weekdayShort(lang, week[i].date.weekday),
                  isToday: i == week.length - 1,
                  delay: i,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _daysRu(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'день';
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'дня';
    return 'дней';
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.day,
    required this.label,
    required this.isToday,
    required this.delay,
  });

  final SinoDay day;
  final String label;
  final bool isToday;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = day.index?.score;
    final color = score == null
        ? theme.colorScheme.outlineVariant
        : levelColor(SinoLevel.of(score));
    const size = 34.0;
    final dot = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: score == null ? null : color,
        border: Border.all(
          color: isToday ? theme.colorScheme.onSurface : color,
          width: isToday ? 2 : 1.5,
        ),
      ),
      child: Text(
        score == null ? '–' : '$score',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: score == null
              ? theme.colorScheme.onSurfaceVariant
              : (color == AppColors.saffron ? AppColors.ink : Colors.white),
        ),
        textScaler: TextScaler.noScaling,
      ),
    );
    return Semantics(
      label: '$label: ${score ?? '–'}',
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 500 + delay * 70),
            curve: Interval(delay * 0.08, 1, curve: Curves.elasticOut),
            builder: (_, v, child) =>
                Transform.scale(scale: v.clamp(0.0, 1.2), child: child),
            child: dot,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              color: isToday
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
