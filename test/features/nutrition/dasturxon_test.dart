import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/core/backend/backend.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/features/nutrition/application/nutrition_providers.dart';
import 'package:sino/features/nutrition/data/dasturxon.dart';
import 'package:sino/features/nutrition/data/models.dart';

final _items = parseDasturxon(File(dasturxonAsset).readAsStringSync());

final _foods = {
  for (final r in jsonDecode(
    File('assets/wellness/foods.json').readAsStringSync(),
  ) as List)
    (r as Map<String, dynamic>)['id'] as String: Food.fromJson(r),
};

DasturxonItem _item(String slug) => _items.firstWhere((i) => i.slug == slug);

/// Portions for [count] × the dish's [unit].
double _servings(String slug, HomeMeasure unit, [double count = 1]) {
  final i = _item(slug);
  final m = i.measures.firstWhere((m) => m.measure == unit);
  return dasturxonServings(_foods[i.foodId]!, m, count: count)!;
}

Food _food(String? portion) =>
    Food(id: 'x', name: const {'uz': 'X'}, kcal: 100, portion: portion);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dasturxon.json', () {
    test('12 dishes, unique, all in foods.json under the same slug', () {
      expect(_items, hasLength(12));
      expect({for (final i in _items) i.slug}, hasLength(12));
      expect({for (final i in _items) i.foodId}, hasLength(12));
      for (final i in _items) {
        final food = _foods[i.foodId];
        expect(food, isNotNull, reason: i.slug);
        expect(food!.slug, i.slug);
        expect(food.portionGrams, isNotNull, reason: i.slug);
      }
    });

    test('measures: grams > 0, no repeats in a dish, all 5 are used', () {
      final used = <HomeMeasure>{};
      for (final i in _items) {
        expect(i.measures, isNotEmpty, reason: i.slug);
        final units = [for (final m in i.measures) m.measure];
        expect(units.toSet(), hasLength(units.length), reason: i.slug);
        for (final m in i.measures) {
          expect(m.grams, greaterThan(0), reason: i.slug);
          // A home measure, not a whole pot.
          expect(m.grams, lessThanOrEqualTo(500), reason: i.slug);
        }
        used.addAll(units);
      }
      expect(used, HomeMeasure.values.toSet());
    });

    test('bad data is rejected', () {
      expect(
        () => parseDasturxon(
          '{"items": [{"slug": "a", "food_id": "x", '
          '"measures": [{"unit": "chelak", "grams": 1}]}]}',
        ),
        throwsFormatException,
      );
      expect(
        () => parseDasturxon(
          '{"items": [{"slug": "a", "food_id": "x", '
          '"measures": [{"unit": "kosa", "grams": 0}]}]}',
        ),
        throwsFormatException,
      );
      expect(
        () => parseDasturxon(
          '{"items": [{"slug": "a", "food_id": "x", "measures": []}]}',
        ),
        throwsFormatException,
      );
    });
  });

  group('measure → portions', () {
    test('portion grams from the catalog text', () {
      expect(_food('300 g').portionGrams, 300);
      expect(_food('62,5 g').portionGrams, 62.5);
      expect(_food('150 г').portionGrams, 150);
      expect(_food('4 dona').portionGrams, isNull);
      expect(_food(null).portionGrams, isNull);
      expect(
        dasturxonServings(_food('1 dona'), _item('palov').measures.first),
        isNull,
      );
    });

    test('typical servings', () {
      expect(_servings('palov', HomeMeasure.likopcha), 1.0);
      expect(_servings('shorva', HomeMeasure.kosa), 1.0);
      expect(_servings('somsa', HomeMeasure.dona, 2), 2.0);
      expect(_servings('manti', HomeMeasure.dona), 0.25);
      expect(_servings('manti', HomeMeasure.dona, 4), 1.0);
      expect(_servings('non', HomeMeasure.dona, 0.5), 1.25);
      expect(_servings('shashlik', HomeMeasure.dona, 3), 1.5);
      expect(_servings('qatiq', HomeMeasure.choyQoshiq), 0.04);
    });

    test('kcal of «1 likopcha palov» and «2 dona somsa»', () {
      final palov = _foods[_item('palov').foodId]!;
      final somsa = _foods[_item('somsa').foodId]!;
      expect(palov.kcal * _servings('palov', HomeMeasure.likopcha), 600);
      expect(somsa.kcal * _servings('somsa', HomeMeasure.dona, 2), 760);
    });
  });

  test('provider joins the dishes with the fake catalog, in order', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        useFakeProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    final dishes = await container.read(dasturxonProvider.future);
    expect(
      [for (final d in dishes) d.item.slug],
      [for (final i in _items) i.slug],
    );
    for (final d in dishes) {
      expect(d.food.id, d.item.foodId);
    }
  });
}
