import 'package:flutter/material.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/emoji_box.dart';
import '../../../../core/widgets/pill.dart';
import '../../data/models.dart';
import '../labels.dart';

/// One training day of the plan: weekday, minutes, ~kcal, exercises.
class PlanDayCard extends StatelessWidget {
  const PlanDayCard({
    super.key,
    required this.day,
    required this.catalog,
    this.onStart,
  });

  final PlanDay day;
  final Map<String, Exercise> catalog;

  /// Opens the player; `null` hides the button.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        uz: '${day.day}-kun',
                        ru: 'День ${day.day}',
                        en: 'Day ${day.day}',
                      ),
                      style: text.bodySmall,
                    ),
                    Text(
                      day.weekday == null
                          ? context.tr(
                              uz: 'Istalgan kun',
                              ru: 'Любой день',
                              en: 'Any day',
                            )
                          : weekdayName(context, day.weekday!),
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Pill(
                '${day.minutes} ${minUnit(context)}',
                color: AppColors.sky,
                icon: Icons.timer_outlined,
              ),
              const SizedBox(width: 6),
              Pill(
                '~${day.kcal} ${kcalUnit(context)}',
                color: AppColors.coral,
                icon: Icons.local_fire_department_rounded,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in day.items)
            if (catalog[item.exerciseId] case final e?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    EmojiBox(
                      emoji: muscleEmoji(e.muscle),
                      color: AppColors.violet,
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.trMap(e.name),
                        style: text.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      doseText(context, item),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          if (onStart != null) ...[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: Key('workouts-start-${day.day}'),
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                context.tr(uz: 'Boshlash', ru: 'Начать', en: 'Start'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
