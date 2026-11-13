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

/// A row of the `foods` catalog. Nutrients are per one [portion].
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
  });

  final String id;

  /// Asset-only readable id (`palov`); `null` for rows from Supabase.
  final String? slug;

  /// `{uz, ru, en}` — show with `context.trMap`.
  final Map<String, dynamic> name;
  final String? emoji;

  /// Portion description, e.g. `300 g`.
  final String? portion;
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

/// A row of `food_logs` with the joined [food] (`select('*, foods(*)')`).
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
    food: Food.fromJson(Map<String, dynamic>.from(m['foods'] as Map)),
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
    'food_id': food.id,
    'foods': food.toJson(),
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
