/// Models of the nutrition feature (tables `foods`, `food_logs`,
/// `water_logs`). Hand-written `fromJson`/`toJson`, no codegen.
library;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `yyyy-MM-dd` for the `date` columns.
String dateKey(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Where a food comes from. Only [catalog] foods are rows of `foods`; the
/// others live inside their diary row (`food_logs.custom_food`).
enum FoodSource {
  /// The `foods` catalog.
  catalog,

  /// Estimated from a photo.
  photo,

  /// Cooked at home: the user listed the ingredients.
  recipe,

  /// A store product (barcode or the popular products list).
  barcode,

  /// «Just calories» — typed by hand.
  quick;

  static FoodSource fromName(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => FoodSource.catalog);
}

/// Prefix of ids of foods that are not in the catalog.
const customFoodPrefix = 'custom-';

/// A food: a row of the `foods` catalog or a custom one ([source] ≠
/// catalog). Nutrients are per one [portion].
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.kcal,
    this.slug,
    this.emoji,
    this.portion,
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
    this.source = FoodSource.catalog,
    this.barcode,
  });

  /// Custom food (not in `foods`) with a fresh id.
  factory Food.custom({
    required FoodSource source,
    required Map<String, dynamic> name,
    required double kcal,
    String? emoji,
    String? portion,
    double protein = 0,
    double fat = 0,
    double carbs = 0,
    String? barcode,
  }) => Food(
    id: '$customFoodPrefix${source.name}-${DateTime.now().microsecondsSinceEpoch}',
    source: source,
    name: name,
    emoji: emoji,
    portion: portion,
    kcal: kcal,
    protein: protein,
    fat: fat,
    carbs: carbs,
    barcode: barcode,
  );

  final String id;

  final FoodSource source;

  /// EAN / UPC of a store product.
  final String? barcode;

  /// Not a row of the `foods` catalog.
  bool get isCustom => source != FoodSource.catalog;

  /// Asset-only readable id (`palov`); `null` for rows from Supabase.
  final String? slug;

  /// `{uz, ru, en}` — show with `context.trMap`.
  final Map<String, dynamic> name;
  final String? emoji;

  /// Portion description, e.g. `300 g`.
  final String? portion;

  /// Grams in one [portion] (`300 g` → 300), `null` if it is not in grams.
  double? get portionGrams {
    final m = _grams.firstMatch(portion ?? '');
    return m == null ? null : double.parse(m[1]!.replaceAll(',', '.'));
  }

  static final _grams = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*(?:g|г)\s*$');

  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  factory Food.fromJson(Map<String, dynamic> m) => Food(
    id: m['id'] as String,
    slug: m['slug'] as String?,
    name: Map<String, dynamic>.from(m['name'] as Map? ?? const {}),
    emoji: m['emoji'] as String?,
    portion: m['portion'] as String?,
    kcal: _d(m['kcal']),
    protein: _d(m['protein']),
    fat: _d(m['fat']),
    carbs: _d(m['carbs']),
    source: FoodSource.fromName(m['source'] as String?),
    barcode: m['barcode'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (slug != null) 'slug': slug,
    'name': name,
    'emoji': emoji,
    'portion': portion,
    'kcal': kcal,
    'protein': protein,
    'fat': fat,
    'carbs': carbs,
    if (isCustom) 'source': source.name,
    if (barcode != null) 'barcode': barcode,
  };
}

enum Meal {
  breakfast,
  lunch,
  dinner,
  snack;

  static Meal fromName(String? s) =>
      values.firstWhere((m) => m.name == s, orElse: () => Meal.snack);
}

/// A row of `food_logs` with the joined [food] (`select('*, foods(*)')`);
/// a custom food comes from `custom_food` instead (then `foods` is null).
class FoodLog {
  const FoodLog({
    required this.id,
    required this.date,
    required this.meal,
    required this.food,
    this.servings = 1,
    this.createdAt,
  });

  final String id;

  /// Day of the log (no time part).
  final DateTime date;
  final Meal meal;
  final Food food;

  /// Number of portions, step 0.5.
  final double servings;
  final DateTime? createdAt;

  double get kcal => food.kcal * servings;
  double get protein => food.protein * servings;
  double get fat => food.fat * servings;
  double get carbs => food.carbs * servings;

  FoodLog copyWith({double? servings}) => FoodLog(
    id: id,
    date: date,
    meal: meal,
    food: food,
    servings: servings ?? this.servings,
    createdAt: createdAt,
  );

  factory FoodLog.fromJson(Map<String, dynamic> m) => FoodLog(
    id: m['id'] as String,
    date: _dateOnly(DateTime.parse(m['date'] as String)),
    meal: Meal.fromName(m['meal'] as String?),
    food: switch ((m['foods'], m['custom_food'])) {
      (final Map f, _) => Food.fromJson(Map<String, dynamic>.from(f)),
      (_, final Map c) => Food.fromJson({
        'id': '$customFoodPrefix${m['id']}',
        'source': FoodSource.quick.name,
        ...Map<String, dynamic>.from(c),
      }),
      _ => throw FormatException('food_logs ${m['id']}: no food'),
    },
    servings: (m['servings'] as num?)?.toDouble() ?? 1,
    createdAt: m['created_at'] == null
        ? null
        : DateTime.parse(m['created_at'] as String).toLocal(),
  );

  /// Same shape as a Supabase row with the `foods` join.
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': dateKey(date),
    'meal': meal.name,
    if (food.isCustom) ...{
      'food_id': null,
      'custom_food': food.toJson(),
    } else ...{
      'food_id': food.id,
      'foods': food.toJson(),
    },
    'servings': servings,
    if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
  };
}

/// A row of `water_logs` (one per user per day).
class WaterLog {
  const WaterLog({required this.date, required this.glasses});

  /// Daily goal, glasses of ~250 ml.
  static const goal = 8;

  final DateTime date;
  final int glasses;

  factory WaterLog.fromJson(Map<String, dynamic> m) => WaterLog(
    date: _dateOnly(DateTime.parse(m['date'] as String)),
    glasses: (m['glasses'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {'date': dateKey(date), 'glasses': glasses};
}
