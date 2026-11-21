import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../application/nutrition_math.dart';
import '../../application/nutrition_providers.dart';
import '../../data/models.dart';
import '../labels.dart';

/// Home card: today's calories against the goal and water glasses with a
/// «+1 glass» button. Tap opens the diary on today.
class NutritionHomeCard extends ConsumerWidget {
  const NutritionHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dayOf(DateTime.now());
    final logs = ref.watch(dayLogsProvider(today));
    final water = ref.watch(waterProvider(today));
    final goal = ref.watch(kcalGoalProvider).value ?? defaultKcalGoal;

    void open() {
      ref.read(selectedDayProvider.notifier).select(today);
      context.go(AppRoutes.nutrition);
    }

    final list = logs.value;
    if (list == null) {
      return ShortcutCard(
        key: const Key('nutrition-home-card'),
        emoji: '🥗',
        title: context.tr(uz: 'Ovqat', ru: 'Питание', en: 'Nutrition'),
        subtitle: logs.hasError
            ? context.tr(
                uz: 'Ma’lumot yuklanmadi — ochib qayta urinib ko‘ring',
                ru: 'Не удалось загрузить — откройте и повторите',
                en: 'Couldn’t load — open to retry',
              )
            : context.tr(uz: 'Yuklanmoqda…', ru: 'Загрузка…', en: 'Loading…'),
        color: AppColors.good,
        onTap: open,
      );
    }

    final theme = Theme.of(context);
    final text = theme.textTheme;
    final eaten = totalsOf(list).kcal.round();
    final left = goal - eaten;
    final over = left < 0;
    final ringColor = over ? AppColors.coral : AppColors.good;
    final unit = kcalUnit(context);
    final glasses = water.value;

    Future<void> addGlass() async {
      final n = glasses;
      if (n == null) return;
      try {
        await ref.read(waterProvider(today).notifier).set(n + 1);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
      }
    }

    return AppCard(
      key: const Key('nutrition-home-card'),
      onTap: open,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(
                value: goal <= 0 ? 0 : eaten / goal,
                size: 56,
                strokeWidth: 6,
                color: ringColor,
                semanticsLabel: context.tr(
                  uz: 'Kaloriya: $eaten / $goal',
                  ru: 'Калории: $eaten / $goal',
                  en: 'Calories: $eaten / $goal',
                ),
                child: const Text('🥗', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        uz: 'Ovqat · bugun',
                        ru: 'Питание · сегодня',
                        en: 'Nutrition · today',
                      ),
                      style: text.bodySmall,
                    ),
                    Text(
                      '$eaten / $goal $unit',
                      key: const Key('nutrition-home-kcal'),
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      over
                          ? context.tr(
                              uz: '${-left} $unit ortiqcha',
                              ru: '${-left} $unit сверх нормы',
                              en: '${-left} $unit over',
                            )
                          : context.tr(
                              uz: '$left $unit qoldi',
                              ru: 'Осталось $left $unit',
                              en: '$left $unit left',
                            ),
                      style: text.bodySmall?.copyWith(
                        color: over ? AppColors.coral : null,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('💧', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                glasses == null
                    ? '… / ${WaterLog.goal}'
                    : '$glasses / ${WaterLog.goal}',
                key: const Key('nutrition-home-water'),
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              Text(
                context.tr(uz: 'stakan', ru: 'стак.', en: 'glasses'),
                style: text.bodySmall,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: LinearProgressIndicator(
                    value: ((glasses ?? 0) / WaterLog.goal).clamp(0.0, 1.0),
                    minHeight: 6,
                    color: AppColors.sky,
                    backgroundColor: AppColors.sky.withValues(alpha: 0.15),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                key: const Key('nutrition-home-water-plus'),
                visualDensity: VisualDensity.compact,
                tooltip: context.tr(
                  uz: '+1 stakan suv',
                  ru: '+1 стакан воды',
                  en: '+1 glass of water',
                ),
                onPressed: glasses == null || glasses >= maxWaterGlasses
                    ? null
                    : addGlass,
                icon: const Icon(Icons.add_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
