import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../application/nutrition_providers.dart';
import '../labels.dart';

/// ‹ Bugun › — previous / next day, tap the label to pick a date.
class DaySwitcher extends ConsumerWidget {
  const DaySwitcher({super.key, this.onDark = false});

  /// White arrows and label for a gradient header.
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final notifier = ref.read(selectedDayProvider.notifier);
    final today = dayOf(DateTime.now());
    final first = DateTime(
      today.year,
      today.month,
      today.day - nutritionHistoryDays,
    );
    final isToday = !day.isBefore(today);
    final isFirst = !day.isAfter(first);
    final base = Theme.of(context);
    final theme = onDark ? _onDarkTheme(base) : base;

    final row = Row(
      children: [
        IconButton(
          tooltip: context.tr(
            uz: 'Oldingi kun',
            ru: 'Предыдущий день',
            en: 'Previous day',
          ),
          onPressed: isFirst ? null : () => notifier.shift(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: TextButton.icon(
            key: const Key('nutrition-day-label'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: day.isBefore(first)
                    ? first
                    : (day.isAfter(today) ? today : day),
                firstDate: first,
                lastDate: today,
              );
              if (picked != null) notifier.select(picked);
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text(
              dayLabel(context, day, today),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: context.tr(
            uz: 'Keyingi kun',
            ru: 'Следующий день',
            en: 'Next day',
          ),
          onPressed: isToday ? null : () => notifier.shift(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
    return onDark ? Theme(data: theme, child: row) : row;
  }

  static ThemeData _onDarkTheme(ThemeData base) {
    const white = Colors.white;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: white,
        onSurface: white,
        onSurfaceVariant: white,
      ),
      iconTheme: const IconThemeData(color: white),
      textTheme: base.textTheme.apply(bodyColor: white, displayColor: white),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: white),
      ),
    );
  }
}
