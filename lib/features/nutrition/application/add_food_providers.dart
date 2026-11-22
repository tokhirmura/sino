import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend.dart';
import '../../../core/storage/prefs.dart';
import '../data/ingredients.dart';
import '../data/models.dart';
import '../data/nutrition_repository.dart';
import '../data/products.dart';
import 'nutrition_math.dart';

/// Raw ingredients for «O‘zim pishirdim».
final ingredientsProvider = FutureProvider<List<Ingredient>>(
  (ref) => loadIngredients(),
);

/// «Recently eaten» in the add sheet — reloaded each time the sheet opens.
final recentFoodsProvider =
    FutureProvider.autoDispose<List<({Food food, double servings})>>((
      ref,
    ) async {
      ref.watch(authStateProvider);
      final logs = await ref.watch(nutritionRepositoryProvider).latestLogs();
      return recentFoods(logs, limit: 8);
    });

/// Popular store products + the ones the user entered / scanned.
final popularProductsProvider = FutureProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(productsRepositoryProvider).popular(),
);

/// Products matching [query] (uz/ru/en name), all when it is empty.
List<Product> searchProducts(List<Product> products, String query) {
  final q = normalizeFoodText(query);
  if (q.isEmpty) return products;
  return [
    for (final p in products)
      if (p.name.values.any((n) => normalizeFoodText('$n').contains(q)) ||
          p.barcodes.contains(query.trim()))
        p,
  ];
}

/// Recipe totals: whole pot and one portion.
class RecipeSummary {
  const RecipeSummary({
    required this.total,
    required this.grams,
    required this.portions,
  });

  final NutrientTotals total;

  /// Weight of all (raw) ingredients.
  final double grams;
  final int portions;

  NutrientTotals get perPortion => NutrientTotals(
    kcal: total.kcal / portions,
    protein: total.protein / portions,
    fat: total.fat / portions,
    carbs: total.carbs / portions,
  );

  double get portionGrams => grams / portions;

  /// Share of calories from fat (0…1).
  double get fatShare => total.kcal <= 0 ? 0 : total.fat * 9 / total.kcal;

  /// More than 40 % of calories from fat — worth a hint.
  bool get fatty => fatShare > 0.4 && total.kcal > 0;
}

/// Most portions one pot can make.
const maxRecipePortions = 30;

RecipeSummary summarizeRecipe(List<RecipeLine> lines, int portions) {
  var t = const NutrientTotals();
  var g = 0.0;
  for (final l in lines) {
    t += NutrientTotals(
      kcal: l.kcal,
      protein: l.protein,
      fat: l.fat,
      carbs: l.carbs,
    );
    g += l.grams;
  }
  return RecipeSummary(
    total: t,
    grams: g,
    portions: portions.clamp(1, maxRecipePortions),
  );
}

/// One portion of a homemade dish as a diary food.
Food recipeFood({
  required String name,
  required RecipeSummary summary,
  String emoji = '🍲',
}) {
  final p = summary.perPortion;
  double r(double v) => (v * 10).roundToDouble() / 10;
  final title = name.trim();
  return Food.custom(
    source: FoodSource.recipe,
    name: {'uz': title, 'ru': title, 'en': title},
    emoji: emoji,
    portion: '${summary.portionGrams.round()} g',
    kcal: r(p.kcal),
    protein: r(p.protein),
    fat: r(p.fat),
    carbs: r(p.carbs),
  );
}

/// «Mening retseptlarim»: a recipe the user can cook again.
class SavedRecipe {
  const SavedRecipe({
    required this.name,
    required this.text,
    this.portions = 4,
    this.emoji = '🍲',
  });

  final String name;

  /// What was typed in «what did you put in».
  final String text;
  final int portions;
  final String emoji;

  factory SavedRecipe.fromJson(Map<String, dynamic> m) => SavedRecipe(
    name: m['name'] as String,
    text: m['text'] as String,
    portions: (m['portions'] as num?)?.toInt() ?? 4,
    emoji: m['emoji'] as String? ?? '🍲',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'text': text,
    'portions': portions,
    'emoji': emoji,
  };
}

/// Saved recipes (prefs, per device), newest first, one per name.
class MyRecipesNotifier extends Notifier<List<SavedRecipe>> {
  static const key = 'nutrition.my_recipes';
  static const maxRecipes = 20;

  @override
  List<SavedRecipe> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(key);
    if (raw == null) return const [];
    try {
      return [
        for (final m in jsonDecode(raw) as List)
          SavedRecipe.fromJson(Map<String, dynamic>.from(m as Map)),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(SavedRecipe recipe) => _set([
    recipe,
    for (final r in state)
      if (normalizeFoodText(r.name) != normalizeFoodText(recipe.name)) r,
  ]);

  Future<void> remove(String name) => _set([
    for (final r in state)
      if (r.name != name) r,
  ]);

  Future<void> _set(List<SavedRecipe> list) async {
    state = list.take(maxRecipes).toList();
    await ref
        .read(sharedPreferencesProvider)
        .setString(key, jsonEncode([for (final r in state) r.toJson()]));
  }
}

final myRecipesProvider =
    NotifierProvider<MyRecipesNotifier, List<SavedRecipe>>(
      MyRecipesNotifier.new,
    );
