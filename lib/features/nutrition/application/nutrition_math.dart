import '../data/models.dart';

/// Calories and macros (protein / fat / carbs in grams).
class NutrientTotals {
  const NutrientTotals({
    this.kcal = 0,
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
  });

  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  /// «Non birligi» (bread unit): 12 g of carbohydrates.
  double get breadUnits => carbs / 12;

  NutrientTotals operator +(NutrientTotals o) => NutrientTotals(
    kcal: kcal + o.kcal,
    protein: protein + o.protein,
    fat: fat + o.fat,
    carbs: carbs + o.carbs,
  );

  static NutrientTotals ofLog(FoodLog l) => NutrientTotals(
    kcal: l.kcal,
    protein: l.protein,
    fat: l.fat,
    carbs: l.carbs,
  );
}

/// Sum of all [logs] (servings counted).
NutrientTotals totalsOf(Iterable<FoodLog> logs) => logs
    .map(NutrientTotals.ofLog)
    .fold(const NutrientTotals(), (a, b) => a + b);

/// Totals per meal; every [Meal] is present (zero when empty).
Map<Meal, NutrientTotals> totalsByMeal(Iterable<FoodLog> logs) => {
  for (final m in Meal.values) m: totalsOf(logs.where((l) => l.meal == m)),
};

/// Sex constant of Mifflin–St Jeor. The profile has no sex field, so
/// [average] (midpoint of +5 and −161) is the default.
enum BmrSex {
  male(5),
  female(-161),
  average(-78);

  const BmrSex(this.constant);
  final int constant;
}

/// Basal metabolic rate, kcal/day (Mifflin–St Jeor):
/// `10·weight + 6.25·height − 5·age + s`.
double mifflinStJeor({
  required double weightKg,
  required double heightCm,
  required int age,
  BmrSex sex = BmrSex.average,
}) => 10 * weightKg + 6.25 * heightCm - 5 * age + sex.constant;

/// Light activity (1–3 workouts a week).
const defaultActivityFactor = 1.375;

/// Fallback goal when the profile lacks height, weight or birth year.
const defaultKcalGoal = 2000;

/// Daily calorie goal from the profile, rounded to 10 kcal.
/// `null` when height, weight or birth year is missing.
int? dailyKcalGoal({
  required double? weightKg,
  required double? heightCm,
  required int? birthYear,
  required int currentYear,
  BmrSex sex = BmrSex.average,
  double activity = defaultActivityFactor,
}) {
  if (weightKg == null || heightCm == null || birthYear == null) return null;
  if (weightKg <= 0 || heightCm <= 0) return null;
  final age = (currentYear - birthYear).clamp(10, 100);
  final bmr = mifflinStJeor(
    weightKg: weightKg,
    heightCm: heightCm,
    age: age,
    sex: sex,
  );
  return ((bmr * activity) / 10).round() * 10;
}

/// Macro goals in grams for [kcalGoal]: protein 20 %, fat 30 %,
/// carbs 50 % of calories (4 / 9 / 4 kcal per gram).
NutrientTotals macroGoals(num kcalGoal) => NutrientTotals(
  kcal: kcalGoal.toDouble(),
  protein: kcalGoal * 0.20 / 4,
  fat: kcalGoal * 0.30 / 9,
  carbs: kcalGoal * 0.50 / 4,
);

/// Servings step in the diary.
const servingsStep = 0.5;

/// Clamps and snaps [v] to the 0.5 grid, minimum one step.
double snapServings(double v) {
  final snapped = (v / servingsStep).round() * servingsStep;
  return snapped < servingsStep ? servingsStep : snapped;
}
