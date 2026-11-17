import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/emoji_box.dart';
import '../../../../core/widgets/pill.dart';
import '../../application/plan_generator.dart';
import '../../application/workouts_providers.dart';
import '../labels.dart';
import '../workout_player_screen.dart';

/// Home card: the next training of the plan (when, minutes, ~kcal,
/// exercises) and the streak; without a plan — an invitation to build one.
class WorkoutsHomeCard extends ConsumerWidget {
  const WorkoutsHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(nextWorkoutProvider);
    final streak = ref.watch(streakProvider).value ?? 0;
    void open() => context.go(AppRoutes.workouts);

    ShortcutCard shortcut(String subtitle) => ShortcutCard(
      key: const Key('workouts-home-card'),
      emoji: '🏃',
      title: context.tr(uz: 'Sport', ru: 'Тренировки', en: 'Workouts'),
      subtitle: subtitle,
      color: AppColors.violet,
      onTap: open,
    );

    if (next.hasError && !next.hasValue) {
      return shortcut(
        context.tr(
          uz: 'Ma’lumot yuklanmadi — ochib qayta urinib ko‘ring',
          ru: 'Не удалось загрузить — откройте и повторите',
          en: 'Couldn’t load — open to retry',
        ),
      );
    }
    if (!next.hasValue) {
      return shortcut(
        context.tr(uz: 'Yuklanmoqda…', ru: 'Загрузка…', en: 'Loading…'),
      );
    }
    final n = next.value;
    if (n == null) {
      return shortcut(
        context.tr(
          uz: 'Haftalik mashg‘ulot rejangizni tuzing — 1 daqiqa',
          ru: 'Составьте план тренировок на неделю — 1 минута',
          en: 'Build your weekly workout plan — 1 minute',
        ),
      );
    }

    final text = Theme.of(context).textTheme;
    final params = PlanParams.fromJson(n.plan.params);
    final today = DateTime.now();
    final daysAway = DateTime(
      n.date.year,
      n.date.month,
      n.date.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    final weekday = weekdayName(context, n.date.weekday);
    final when = switch (daysAway) {
      0 => context.tr(uz: 'Bugun', ru: 'Сегодня', en: 'Today'),
      1 => context.tr(uz: 'Ertaga', ru: 'Завтра', en: 'Tomorrow'),
      _ => weekday,
    };
    final count = n.day.items.length;

    return AppCard(
      key: const Key('workouts-home-card'),
      onTap: open,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          EmojiBox(emoji: params.type.emoji, color: AppColors.violet),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    uz: 'Keyingi mashg‘ulot',
                    ru: 'Следующая тренировка',
                    en: 'Next workout',
                  ),
                  style: text.bodySmall,
                ),
                Text(
                  daysAway <= 1 ? '$when · $weekday' : when,
                  key: const Key('workouts-home-when'),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    '${n.day.minutes} ${minUnit(context)}',
                    '~${n.day.kcal} ${kcalUnit(context)}',
                    context.tr(
                      uz: '$count ta mashq',
                      ru: '$count упр.',
                      en: '$count exercises',
                    ),
                  ].join(' · '),
                  key: const Key('workouts-home-details'),
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (streak > 0) ...[
            const SizedBox(width: 8),
            Pill(
              '🔥 $streak',
              key: const Key('workouts-home-streak'),
              color: AppColors.amber,
            ),
          ],
          if (daysAway == 0) ...[
            const SizedBox(width: 6),
            IconButton.filled(
              key: const Key('workouts-home-start'),
              tooltip: context.tr(
                uz: 'Mashg‘ulotni boshlash',
                ru: 'Начать тренировку',
                en: 'Start workout',
              ),
              onPressed: () => context.push(workoutPlayerPath(n.day.day)),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ] else
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}
