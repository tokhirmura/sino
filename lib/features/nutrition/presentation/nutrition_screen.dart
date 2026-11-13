import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
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

    return AppScaffold(
      title: context.tr(uz: 'Ovqat', ru: 'Питание', en: 'Nutrition'),
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
            const DaySwitcher(),
            AsyncValueView(
              value: logs,
              onRetry: () => ref.invalidate(logsProvider),
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SkeletonList(count: 3, itemHeight: 140),
              ),
              data: (list) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CalorieSummaryCard(totals: totalsOf(list), goal: goal),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 20),
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
