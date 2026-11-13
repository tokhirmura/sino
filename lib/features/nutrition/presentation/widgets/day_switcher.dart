import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../application/nutrition_providers.dart';
import '../labels.dart';

/// ‹ Bugun › — previous / next day, tap the label to pick a date.
class DaySwitcher extends ConsumerWidget {
  const DaySwitcher({super.key});

  /// How far back the calendar goes.
  static const historyDays = 365;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final notifier = ref.read(selectedDayProvider.notifier);
    final today = dayOf(DateTime.now());
    final isToday = !day.isBefore(today);
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton(
          tooltip: context.tr(
            uz: 'Oldingi kun',
            ru: 'Предыдущий день',
            en: 'Previous day',
          ),
          onPressed: () => notifier.shift(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: TextButton.icon(
            key: const Key('nutrition-day-label'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: today.subtract(const Duration(days: historyDays)),
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
  }
}
