import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/features/nutrition/application/nutrition_math.dart';
import 'package:sino/features/nutrition/data/models.dart';
import 'package:sino/features/nutrition/data/nutrition_repository.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

List<Map<String, dynamic>> _asset(String name) => [
  for (final r
      in jsonDecode(File('assets/wellness/$name').readAsStringSync()) as List)
    r as Map<String, dynamic>,
];

Food _food({double kcal = 100, double p = 10, double f = 5, double c = 24}) =>
    Food(
      id: 'x',
      name: const {'uz': 'X'},
      kcal: kcal,
      protein: p,
      fat: f,
      carbs: c,
    );

FoodLog _log(Meal meal, Food food, double servings) => FoodLog(
  id: '$meal$servings',
  date: DateTime(2026, 11, 14),
  meal: meal,
  food: food,
  servings: servings,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('foods.json', () {
    final rows = _asset('foods.json');

    test('40 foods with unique uuid ids and 3 languages', () {
      expect(rows, hasLength(40));
      expect({for (final r in rows) r['id']}, hasLength(40));
      for (final r in rows) {
        expect(r['id'], matches(_uuid));
        final name = r['name'] as Map;
        for (final l in ['uz', 'ru', 'en']) {
          expect((name[l] as String).trim(), isNotEmpty, reason: '${r['id']}');
        }
      }
    });

    test('nutrients are non-negative and match the table columns', () {
      const columns = {
        'id', 'slug', 'name', 'emoji', 'portion', //
        'kcal', 'protein', 'fat', 'carbs',
      };
      for (final r in rows) {
        expect(columns.containsAll(r.keys), isTrue, reason: '${r.keys}');
        for (final k in ['kcal', 'protein', 'fat', 'carbs']) {
          expect(r[k] as num, greaterThanOrEqualTo(0));
        }
      }
    });
  });

  group('models', () {
    test('FoodLog parses a Supabase row with the foods join', () {
      final log = FoodLog.fromJson({
        'id': 'l1',
        'user_id': 'u1',
        'date': '2026-11-14',
        'meal': 'lunch',
        'food_id': 'f1',
        'servings': 1.5,
        'created_at': '2026-11-14T08:00:00+00:00',
        'foods': {
          'id': 'f1',
          'name': {'uz': 'Palov', 'ru': 'Плов', 'en': 'Plov'},
          'emoji': '🍛',
          'portion': '300 g',
          'kcal': 600,
          'protein': 18,
          'fat': 30,
          'carbs': 64,
        },
      });
      expect(log.meal, Meal.lunch);
      expect(log.date, DateTime(2026, 11, 14));
      expect(log.kcal, 900);
      expect(log.food.name['ru'], 'Плов');
    });

    test('toJson → fromJson round trip', () {
      final log = _log(Meal.dinner, _food(), 2);
      final back = FoodLog.fromJson(log.toJson());
      expect(back.meal, Meal.dinner);
      expect(back.servings, 2);
      expect(back.food.kcal, 100);
      expect(dateKey(back.date), '2026-11-14');
    });
  });

  group('math', () {
    test('totals count servings and group by meal', () {
      final food = _food();
      final logs = [
        _log(Meal.breakfast, food, 1),
        _log(Meal.lunch, food, 0.5),
        _log(Meal.lunch, food, 2),
      ];
      final t = totalsOf(logs);
      expect(t.kcal, 350);
      expect(t.carbs, 84);
      expect(t.breadUnits, 7);
      final byMeal = totalsByMeal(logs);
      expect(byMeal.keys, Meal.values);
      expect(byMeal[Meal.lunch]!.kcal, 250);
      expect(byMeal[Meal.dinner]!.kcal, 0);
    });

    test('Mifflin–St Jeor', () {
      expect(
        mifflinStJeor(weightKg: 80, heightCm: 180, age: 30, sex: BmrSex.male),
        1780,
      );
      expect(
        mifflinStJeor(weightKg: 60, heightCm: 165, age: 25, sex: BmrSex.female),
        1345.25,
      );
      // average sex constant −78, light activity 1.375, rounded to 10
      expect(
        dailyKcalGoal(
          weightKg: 80,
          heightCm: 180,
          birthYear: 1996,
          currentYear: 2026,
        ),
        2330,
      );
      expect(
        dailyKcalGoal(
          weightKg: null,
          heightCm: 180,
          birthYear: 1996,
          currentYear: 2026,
        ),
        isNull,
      );
    });

    test('macro goals and servings step', () {
      final g = macroGoals(2000);
      expect(g.protein, 100);
      expect(g.carbs, 250);
      expect(g.fat, closeTo(66.7, 0.1));
      expect(snapServings(1.3), 1.5);
      expect(snapServings(0.1), 0.5);
      expect(snapServings(2.74), 2.5);
    });
  });

  group('FakeNutritionRepository', () {
    late FakeNutritionRepository repo;
    final today = DateTime(2026, 11, 14);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = FakeNutritionRepository(
        await SharedPreferences.getInstance(),
        now: today,
      );
    });

    test('search works in uz/ru/en, ignores apostrophes and case', () async {
      final foods = await repo.foods();
      expect(foods, hasLength(40));
      List<String?> slugs(String q) => [
        for (final f in searchFoods(foods, q)) f.slug,
      ];
      expect(slugs('lagmon'), contains('lagmon'));
      expect(slugs('Лагман'), contains('lagmon'));
      expect(slugs("go'shtli"), contains('somsa'));
      expect(slugs('PLOV'), contains('palov'));
      expect(searchFoods(foods, '  '), hasLength(40));
      expect(slugs('zzzz'), isEmpty);
    });

    test('demo diary and water for today and yesterday', () async {
      final logs = await repo.logsFor(today);
      expect(logs.map((l) => l.food.slug), containsAll(['lagmon', 'non']));
      expect(await repo.waterFor(today), 3);
      expect(
        await repo.logsFor(today.subtract(const Duration(days: 1))),
        isNotEmpty,
      );
      expect(await repo.logsFor(DateTime(2020)), isEmpty);
    });

    test('add, update servings, remove', () async {
      final day = DateTime(2026, 11, 20);
      final palov = (await repo.foods()).firstWhere((f) => f.slug == 'palov');
      final log = await repo.addLog(day: day, meal: Meal.lunch, food: palov);
      expect(totalsOf(await repo.logsFor(day)).kcal, 600);

      await repo.updateServings(log.id, 1.5);
      expect(totalsOf(await repo.logsFor(day)).kcal, 900);

      await repo.removeLog(log.id);
      expect(await repo.logsFor(day), isEmpty);
    });

    test('water is stored per day and never negative', () async {
      final day = DateTime(2026, 11, 20);
      await repo.setWater(day, 5);
      expect(await repo.waterFor(day), 5);
      await repo.setWater(day, -1);
      expect(await repo.waterFor(day), 0);
      expect(await repo.waterFor(today), 3);
    });
  });
}
