import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/emoji_box.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../application/nutrition_math.dart';
import '../../application/nutrition_providers.dart';
import '../../data/models.dart';
import '../../data/nutrition_repository.dart';
import '../labels.dart';

/// What the user picked in [showAddFoodSheet].
class FoodChoice {
  const FoodChoice(this.food, this.meal, this.servings);

  final Food food;
  final Meal meal;
  final double servings;
}

/// Bottom sheet: meal chips, portions (step 0.5), search in the catalog.
/// Tapping a food closes the sheet with the choice.
Future<FoodChoice?> showAddFoodSheet(
  BuildContext context, {
  required Meal meal,
}) => showModalBottomSheet<FoodChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.9,
    child: _AddFoodSheet(initialMeal: meal),
  ),
);

class _AddFoodSheet extends ConsumerStatefulWidget {
  const _AddFoodSheet({required this.initialMeal});

  final Meal initialMeal;

  @override
  ConsumerState<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends ConsumerState<_AddFoodSheet> {
  late Meal _meal = widget.initialMeal;
  double _servings = 1;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final catalog = ref.watch(foodsCatalogProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(
              uz: 'Ovqat qo‘shish',
              ru: 'Добавить еду',
              en: 'Add food',
            ),
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          // Wrap, not a scrolling row: all four meals stay visible on a
          // small phone.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in Meal.values)
                ChoiceChip(
                  key: Key('nutrition-meal-chip-${m.name}'),
                  label: Text('${m.emoji} ${m.label(context)}'),
                  selected: _meal == m,
                  onSelected: (_) => setState(() => _meal = m),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(uz: 'Porsiya', ru: 'Порция', en: 'Portion'),
                  style: text.titleSmall,
                ),
              ),
              IconButton.filledTonal(
                tooltip: context.tr(
                  uz: 'Kamaytirish',
                  ru: 'Меньше',
                  en: 'Less',
                ),
                onPressed: _servings > servingsStep
                    ? () => setState(
                        () =>
                            _servings = snapServings(_servings - servingsStep),
                      )
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '× ${formatServings(_servings)}',
                  key: const Key('nutrition-sheet-servings'),
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: context.tr(
                  uz: 'Ko‘paytirish',
                  ru: 'Больше',
                  en: 'More',
                ),
                onPressed: _servings < maxServings
                    ? () => setState(
                        () =>
                            _servings = snapServings(_servings + servingsStep),
                      )
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('nutrition-search-field'),
            autofocus: false,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: context.tr(
                uz: 'Masalan: palov, somsa, olma',
                ru: 'Например: плов, самса, яблоко',
                en: 'E.g. plov, samsa, apple',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AsyncValueView(
              value: catalog,
              onRetry: () => ref.invalidate(foodsCatalogProvider),
              data: (foods) {
                final found = searchFoods(foods, _query);
                if (found.isEmpty) {
                  return EmptyState(
                    emoji: '🔍',
                    title: context.tr(
                      uz: 'Hech narsa topilmadi',
                      ru: 'Ничего не найдено',
                      en: 'Nothing found',
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: found.length,
                  itemBuilder: (context, i) => _FoodTile(
                    food: found[i],
                    servings: _servings,
                    color: _meal.color,
                    onTap: () =>
                        Navigator.of(context)
                            .pop(FoodChoice(found[i], _meal, _servings)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({
    required this.food,
    required this.servings,
    required this.color,
    required this.onTap,
  });

  final Food food;
  final double servings;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = gramUnit(context);
    final macros = context.tr(
      uz:
          'O ${food.protein.round()}$g · Y ${food.fat.round()}$g · '
          'U ${food.carbs.round()}$g',
      ru:
          'Б ${food.protein.round()}$g · Ж ${food.fat.round()}$g · '
          'У ${food.carbs.round()}$g',
      en:
          'P ${food.protein.round()}$g · F ${food.fat.round()}$g · '
          'C ${food.carbs.round()}$g',
    );
    return ListTile(
      key: Key('nutrition-food-${food.id}'),
      contentPadding: EdgeInsets.zero,
      leading: EmojiBox(emoji: food.emoji ?? '🍽️', color: color, size: 44),
      title: Text(context.trMap(food.name)),
      subtitle: Text(
        [if (food.portion != null) food.portion!, macros].join(' · '),
      ),
      trailing: Text(
        '${(food.kcal * servings).round()} ${kcalUnit(context)}',
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      onTap: onTap,
    );
  }
}
