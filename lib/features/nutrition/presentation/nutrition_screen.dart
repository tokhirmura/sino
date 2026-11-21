import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/nutrition_math.dart';
import '../application/nutrition_providers.dart';
import '../data/models.dart';
import 'labels.dart';
import 'widgets/add_food_sheet.dart';
import 'widgets/calorie_summary_card.dart';
import 'widgets/day_switcher.dart';
import 'widgets/meal_section.dart';
import 'widgets/water_card.dart';

/// «Ovqat» tab: diary of the selected day by meals, calorie ring with
/// macros, water glasses.
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final logsProvider = dayLogsProvider(day);
    final logs = ref.watch(logsProvider);
    // A broken profile must not hide the diary — fall back to the default.
    final goal = ref.watch(kcalGoalProvider).value ?? defaultKcalGoal;

    Future<void> add(Meal meal) async {
      final choice = await showAddFoodSheet(context, meal: meal);
      if (choice == null) return;
      try {
        await ref
            .read(logsProvider.notifier)
            .add(choice.food, choice.meal, servings: choice.servings);
      } catch (e) {
        if (context.mounted) _snack(context, errorMessage(context, e));
      }
    }

    Future<void> setServings(FoodLog log, double servings) async {
      try {
        await ref.read(logsProvider.notifier).setServings(log.id, servings);
      } catch (e) {
        if (context.mounted) _snack(context, errorMessage(context, e));
      }
    }

    Future<void> remove(FoodLog log) async {
      final notifier = ref.read(logsProvider.notifier);
      try {
        final removed = await notifier.remove(log.id);
        if (removed == null || !context.mounted) return;
        _snack(
          context,
          context.tr(
            uz: '«${context.trMap(removed.food.name)}» o‘chirildi',
            ru: '«${context.trMap(removed.food.name)}» удалено',
            en: '“${context.trMap(removed.food.name)}” removed',
          ),
          action: SnackBarAction(
            label: context.tr(uz: 'Qaytarish', ru: 'Вернуть', en: 'Undo'),
            onPressed: () async {
              try {
                await notifier.add(
                  removed.food,
                  removed.meal,
                  servings: removed.servings,
                );
              } catch (e) {
                if (context.mounted) _snack(context, errorMessage(context, e));
              }
            },
          ),
        );
      } catch (e) {
        if (context.mounted) _snack(context, errorMessage(context, e));
      }
    }

    final list = logs.value;
    final water = ref.watch(waterProvider(day)).value;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('nutrition-add-fab'),
        onPressed: () => add(MealLabel.forHour(DateTime.now().hour)),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr(uz: 'Qo‘shish', ru: 'Добавить', en: 'Add')),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(logsProvider);
          ref.invalidate(waterProvider(day));
          ref.invalidate(kcalGoalFromProfileProvider);
          await ref
              .read(logsProvider.future)
              .catchError((Object _) => <FoodLog>[]);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _Header(
              eaten: list == null ? null : totalsOf(list).kcal.round(),
              water: water,
              goal: goal,
            ),
            Padding(
              padding: AppSpacing.screen,
              child: AsyncValueView(
                value: logs,
                onRetry: () => ref.invalidate(logsProvider),
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.cardGap),
                  child: SkeletonLoader(count: 3, kind: SkeletonKind.card),
                ),
                data: (list) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.cardGap),
                    if (list.isEmpty) ...[
                      EmptyState(
                        key: const Key('nutrition-empty'),
                        emoji: '🍽️',
                        title: context.tr(
                          uz: 'Bu kunda hali taom yo‘q',
                          ru: 'За этот день пока пусто',
                          en: 'Nothing logged for this day',
                        ),
                        message: context.tr(
                          uz:
                              'Nonushtadan boshlang — kaloriya va BJU o‘zi '
                              'hisoblanadi.',
                          ru:
                              'Начните с завтрака — калории и БЖУ посчитаются '
                              'сами.',
                          en:
                              'Start with breakfast — calories and macros add '
                              'up by themselves.',
                        ),
                        actionLabel: context.tr(
                          uz: 'Taom qo‘shish',
                          ru: 'Добавить еду',
                          en: 'Add food',
                        ),
                        actionIcon: Icons.add_rounded,
                        onAction: () =>
                            add(MealLabel.forHour(DateTime.now().hour)),
                      ),
                      const SizedBox(height: AppSpacing.cardGap),
                    ],
                    CalorieSummaryCard(totals: totalsOf(list), goal: goal),
                    const SizedBox(height: AppSpacing.cardGap),
                    WaterCard(day: day),
                    for (final meal in Meal.values)
                      MealSection(
                        meal: meal,
                        logs: [
                          for (final l in list)
                            if (l.meal == meal) l,
                        ],
                        onAdd: () => add(meal),
                        onServings: setServings,
                        onRemove: remove,
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      context.tr(
                        uz:
                            'Kaloriya va BJU taxminiy. Shifokor maslahatini '
                            'almashtirmaydi.',
                        ru:
                            'Калории и БЖУ приблизительные. Не заменяет '
                            'консультацию врача.',
                        en:
                            'Calories and macros are estimates. Does not '
                            'replace a doctor’s advice.',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _snack(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }
}

/// Gradient header: title, day switcher and the day's numbers.
class _Header extends StatelessWidget {
  const _Header({required this.eaten, required this.water, required this.goal});

  /// `null` while the diary loads.
  final int? eaten;
  final int? water;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final kcal = kcalUnit(context);
    final ml = (water ?? 0) * 250;
    return GradientHeader(
      title: context.tr(uz: 'Ovqat', ru: 'Питание', en: 'Nutrition'),
      subtitle: context.tr(
        uz: 'Kunlik ratsion, BJU va suv',
        ru: 'Рацион, БЖУ и вода за день',
        en: 'Meals, macros and water',
      ),
      child: Column(
        children: [
          const DaySwitcher(onDark: true),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _CountUp(
                  value: eaten,
                  builder: (v) => StatTile(
                    key: const Key('nutrition-header-eaten'),
                    value: v,
                    unit: kcal,
                    label: context.tr(
                      uz: 'Yeyildi',
                      ru: 'Съедено',
                      en: 'Eaten',
                    ),
                    emoji: '🔥',
                    color: AppColors.saffron,
                    onDark: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: StatTile(
                  value: water == null
                      ? '—'
                      : (ml / 1000).toStringAsFixed(ml % 1000 == 0 ? 0 : 2),
                  unit: context.tr(uz: 'l', ru: 'л', en: 'L'),
                  label: context.tr(uz: 'Suv', ru: 'Вода', en: 'Water'),
                  emoji: '💧',
                  color: AppColors.sky,
                  onDark: true,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: StatTile(
                  value: '$goal',
                  unit: kcal,
                  label: context.tr(uz: 'Maqsad', ru: 'Цель', en: 'Goal'),
                  emoji: '🎯',
                  color: AppColors.good,
                  onDark: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A number that counts smoothly to [value] (`null` → «—»).
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.builder});

  final int? value;
  final Widget Function(String text) builder;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) return builder('—');
    return TweenAnimationBuilder<double>(
      tween: Tween(end: v.toDouble()),
      duration: AppMotion.slow,
      curve: AppMotion.enter,
      builder: (_, x, _) => builder('${x.round()}'),
    );
  }
}
