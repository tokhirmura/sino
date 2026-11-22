import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../application/add_food_providers.dart';
import '../../application/nutrition_math.dart';
import '../../application/nutrition_providers.dart';
import '../../data/models.dart';
import '../../data/nutrition_repository.dart';
import '../barcode_food_screen.dart';
import '../labels.dart';
import '../photo_food_screen.dart';
import '../recipe_screen.dart';
import 'quick_kcal_dialog.dart';

/// What the user picked in [showAddFoodSheet].
class FoodChoice {
  const FoodChoice(this.food, this.meal, this.servings);

  final Food food;
  final Meal meal;
  final double servings;
}

/// Bottom sheet: meal chips, four more ways to add (photo, homemade recipe,
/// barcode, just calories), «recently eaten», portions (step 0.5) and the
/// catalog search. Picking a food anywhere closes the sheet with the choice.
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

  /// Opens a full-screen way to add; its choice closes the sheet too.
  Future<void> _open(Widget Function(Meal meal) page) async {
    final choice = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<FoodChoice>(MaterialPageRoute(builder: (_) => page(_meal)));
    if (choice != null && mounted) Navigator.of(context).pop(choice);
  }

  Future<void> _quick() async {
    final food = await showQuickKcalDialog(context);
    if (food != null && mounted) {
      Navigator.of(context).pop(FoodChoice(food, _meal, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final catalog = ref.watch(foodsCatalogProvider);
    final searching = _query.trim().isNotEmpty;

    final foods = catalog.value;
    final found = foods == null ? null : searchFoods(foods, _query);

    // One scroll view: on a small phone the header scrolls away instead of
    // squeezing the list.
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr(uz: 'Ovqat qo‘shish', ru: 'Добавить еду', en: 'Add food'),
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
        // While searching the list needs the room.
        if (!searching) ...[
          const SizedBox(height: AppSpacing.sm),
          _AddModes(
            onPhoto: () => _open((m) => PhotoFoodScreen(meal: m)),
            onRecipe: () => _open((m) => RecipeScreen(meal: m)),
            onBarcode: () => _open((m) => BarcodeFoodScreen(meal: m)),
            onQuick: _quick,
          ),
          _Recent(
            onPick: (r) =>
                Navigator.of(context)
                    .pop(FoodChoice(r.food, _meal, r.servings)),
          ),
        ],
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
              tooltip: context.tr(uz: 'Kamaytirish', ru: 'Меньше', en: 'Less'),
              onPressed: _servings > servingsStep
                  ? () => setState(
                      () => _servings = snapServings(_servings - servingsStep),
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
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton.filledTonal(
              tooltip: context.tr(uz: 'Ko‘paytirish', ru: 'Больше', en: 'More'),
              onPressed: _servings < maxServings
                  ? () => setState(
                      () => _servings = snapServings(_servings + servingsStep),
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
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          if (found == null)
            SliverToBoxAdapter(
              child: AsyncValueView(
                value: catalog,
                onRetry: () => ref.invalidate(foodsCatalogProvider),
                data: (_) => const SizedBox.shrink(),
              ),
            )
          else if (found.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                emoji: '🔍',
                title: context.tr(
                  uz: 'Hech narsa topilmadi',
                  ru: 'Ничего не найдено',
                  en: 'Nothing found',
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: found.length,
              itemBuilder: (context, i) => _FoodTile(
                food: found[i],
                servings: _servings,
                color: _meal.color,
                onTap: () =>
                    Navigator.of(context)
                        .pop(FoodChoice(found[i], _meal, _servings)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Four big buttons: photo (beta), homemade, barcode, just calories.
class _AddModes extends StatelessWidget {
  const _AddModes({
    required this.onPhoto,
    required this.onRecipe,
    required this.onBarcode,
    required this.onQuick,
  });

  final VoidCallback onPhoto;
  final VoidCallback onRecipe;
  final VoidCallback onBarcode;
  final VoidCallback onQuick;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelSmall;
    final modes = [
      (
        key: 'photo',
        emoji: '📷',
        color: AppColors.violet,
        label: context.tr(uz: 'Rasmdan', ru: 'По фото', en: 'Photo'),
        beta: true,
        onTap: onPhoto,
      ),
      (
        key: 'recipe',
        emoji: '👩‍🍳',
        color: AppColors.saffron,
        label: context.tr(
          uz: 'O‘zim pishirdim',
          ru: 'Своё блюдо',
          en: 'Homemade',
        ),
        beta: false,
        onTap: onRecipe,
      ),
      (
        key: 'barcode',
        emoji: '🏷️',
        color: AppColors.sky,
        label: context.tr(uz: 'Shtrix-kod', ru: 'Штрих-код', en: 'Barcode'),
        beta: false,
        onTap: onBarcode,
      ),
      (
        key: 'quick',
        emoji: '⚡',
        color: AppColors.coral,
        label: context.tr(uz: 'Faqat kkal', ru: 'Только ккал', en: 'Just kcal'),
        beta: false,
        onTap: onQuick,
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < modes.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Pressable(
              child: Material(
                color: modes[i].color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.button),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key('nutrition-mode-${modes[i].key}'),
                  onTap: modes[i].onTap,
                  child: SizedBox(
                    height: 78,
                    child: Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  modes[i].emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  modes[i].label,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: label?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (modes[i].beta)
                          PositionedDirectional(
                            top: 5,
                            end: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: modes[i].color,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.chip,
                                ),
                              ),
                              child: Text(
                                'beta',
                                style: label?.copyWith(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// «Recently eaten»: one tap adds it again with the same portion.
class _Recent extends ConsumerWidget {
  const _Recent({required this.onPick});

  final ValueChanged<({Food food, double servings})> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentFoodsProvider).value ?? const [];
    if (recent.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(
              uz: 'Yaqinda yeganlaringiz',
              ru: 'Недавно ели',
              en: 'Recently eaten',
            ),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final r = recent[i];
                final kcal = (r.food.kcal * r.servings).round();
                return ActionChip(
                  key: Key('nutrition-recent-$i'),
                  visualDensity: VisualDensity.compact,
                  avatar: Text(r.food.emoji ?? '🍽️'),
                  label: Text(
                    '${context.trMap(r.food.name)} · $kcal ${kcalUnit(context)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => onPick(r),
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
