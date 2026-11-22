import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/features/nutrition/application/add_food_providers.dart';
import 'package:sino/features/nutrition/data/food_vision.dart';
import 'package:sino/features/nutrition/data/ingredients.dart';
import 'package:sino/features/nutrition/data/models.dart';
import 'package:sino/features/nutrition/data/nutrition_repository.dart';
import 'package:sino/features/nutrition/data/products.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Ingredient> ings;
  setUpAll(() async => ings = await loadIngredients());

  /// `slug → grams` of what [text] parses to.
  Map<String, double> parse(String text) => {
    for (final l in parseRecipe(text, ings).lines) l.ingredient.slug: l.grams,
  };

  group('parseRecipe', () {
    test('uz lines: numbers, units, pieces, spoons', () {
      expect(
        parse(
          'guruch 500 g\nsabzi 2 ta\n3 osh qoshiq yog‘\n1,5 kg qo‘y go‘shti',
        ),
        {
          'guruch': 500,
          'sabzi': 160, // 2 × 80 g
          'osimlik_yogi': 45, // 3 × 15 g
          'qoy_goshti': 1500,
        },
      );
    });

    test('glued units, either order, commas and «va»', () {
      expect(parse('300g guruch, piyoz 2ta va tuxum 3'), {
        'guruch': 300,
        'piyoz': 180,
        'tuxum': 165,
      });
    });

    test('ru: шт, ст. л., полкило, половина стакана', () {
      expect(parse('яйца 3 шт; масло 2 ст. л.; полкило фарша'), {
        'tuxum': 165,
        'osimlik_yogi': 30,
        'qiyma': 500,
      });
      expect(parse('yarim stakan sut'), {'sut': 100});
    });

    test('longest name wins: butter is not oil, chicken is not beef', () {
      expect(parse('сливочное масло 20 г'), {'sariyog': 20});
      expect(parse('kungaboqar yog‘i 50 g'), {'osimlik_yogi': 50});
      expect(parse('tovuq go‘shti 400 g'), {'tovuq': 400});
      expect(parse('dumba yog‘i 100 g'), {'dumba': 100});
    });

    test('whole-word aliases: «nonushta» is not bread, «сырой» not cheese', () {
      expect(parseRecipe('nonushta', ings).lines, isEmpty);
      expect(parse('сырой рис 100 г'), {'guruch': 100});
    });

    test('several ingredients in one part share its numbers in order', () {
      expect(parse('500 g guruch 300 g sabzi'), {'guruch': 500, 'sabzi': 300});
      expect(parse('guruch 500 g sabzi 300 g'), {'guruch': 500, 'sabzi': 300});
    });

    test('no amount → a piece or 100 g, marked as a guess', () {
      final r = parseRecipe('tuxum\nguruch\ntuz', ings);
      expect([for (final l in r.lines) l.grams], [55, 100, 5]);
      expect(r.lines.every((l) => l.guessed), isTrue);
    });

    test('a bare small number of an uncountable thing is kilograms', () {
      final l = parseRecipe('go‘sht 1', ings).lines.single;
      expect(l.grams, 1000);
      expect(l.guessed, isTrue);
    });

    test('unknown parts are reported, known ones still read', () {
      final r = parseRecipe('guruch 200 g, qandaydir narsa 50 g', ings);
      expect(r.lines.single.ingredient.slug, 'guruch');
      expect(r.unknown, ['qandaydir narsa 50 g']);
    });

    test('every ingredient name in uz / ru / en reads back to itself', () {
      for (final i in ings) {
        for (final lang in ['uz', 'ru', 'en']) {
          final name = '${i.name[lang]}';
          final lines = parseRecipe('$name 100 g', ings).lines;
          expect(
            [for (final l in lines) l.ingredient.slug],
            [i.slug],
            reason: '$lang «$name»',
          );
        }
      }
    });
  });

  test('recipe summary: per portion, fat share, diary food', () {
    final lines = parseRecipe('guruch 500 g\nyog‘ 100 g', ings).lines;
    final s = summarizeRecipe(lines, 4);
    // 500 g rice 1720 kcal + 100 g oil 899 kcal = 2619.
    expect(s.total.kcal, closeTo(2619, 0.01));
    expect(s.perPortion.kcal, closeTo(654.75, 0.01));
    expect(s.portionGrams, 150);
    expect(s.fatty, isFalse); // ~ 36 % from fat
    final f = recipeFood(name: ' Uy palovi ', summary: s);
    expect(f.source, FoodSource.recipe);
    expect(f.isCustom, isTrue);
    expect(f.name, {'uz': 'Uy palovi', 'ru': 'Uy palovi', 'en': 'Uy palovi'});
    expect(f.portion, '150 g');
    expect(f.kcal, 654.8);

    final oily = summarizeRecipe(
      parseRecipe('kartoshka 300 g, yog‘ 60 g', ings).lines,
      2,
    );
    expect(oily.fatty, isTrue);
  });

  group('custom food in the diary', () {
    const day = '2026-11-21';
    final food = Food.custom(
      source: FoodSource.barcode,
      name: const {'uz': 'Nutella', 'ru': 'Nutella', 'en': 'Nutella'},
      emoji: '🍫',
      portion: '20 g',
      kcal: 107.8,
      fat: 6.2,
      barcode: '3017620422003',
    );

    test('toJson / fromJson keep it out of the catalog', () {
      final log = FoodLog(
        id: 'l1',
        date: DateTime(2026, 11, 21),
        meal: Meal.snack,
        food: food,
      );
      final json = log.toJson();
      expect(json['food_id'], isNull);
      expect(json.containsKey('foods'), isFalse);
      expect((json['custom_food'] as Map)['source'], 'barcode');
      final back = FoodLog.fromJson(jsonDecode(jsonEncode(json)));
      expect(back.food.isCustom, isTrue);
      expect(back.food.source, FoodSource.barcode);
      expect(back.food.barcode, '3017620422003');
      expect(back.kcal, 107.8);
    });

    test('a Supabase row: foods null, custom_food set', () {
      final log = FoodLog.fromJson({
        'id': 'uuid-1',
        'date': day,
        'meal': 'lunch',
        'food_id': null,
        'foods': null,
        'servings': 2,
        'custom_food': {
          'name': {'uz': 'Osh', 'ru': 'Osh', 'en': 'Osh'},
          'kcal': 500,
          'source': 'recipe',
        },
      });
      expect(log.food.id, 'custom-uuid-1');
      expect(log.food.source, FoodSource.recipe);
      expect(log.kcal, 1000);
    });

    test('catalog rows still parse as before', () {
      final log = FoodLog.fromJson({
        'id': 'x',
        'date': day,
        'meal': 'lunch',
        'servings': 1,
        'foods': {
          'id': 'f1',
          'name': {'uz': 'Palov'},
          'kcal': 600,
        },
      });
      expect(log.food.isCustom, isFalse);
      expect(log.toJson()['food_id'], 'f1');
    });

    test('fake repository stores it; recent foods have no repeats', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeNutritionRepository(
        await SharedPreferences.getInstance(),
        now: DateTime(2026, 11, 21),
      );
      await repo.addLog(
        day: DateTime(2026, 11, 21),
        meal: Meal.snack,
        food: food,
      );
      await repo.addLog(
        day: DateTime(2026, 11, 21),
        meal: Meal.snack,
        food: food,
      );
      final today = await repo.logsFor(DateTime(2026, 11, 21));
      expect(today.where((l) => l.food.isCustom), hasLength(2));

      final recent = recentFoods(await repo.latestLogs());
      expect(recent.first.food.name['uz'], 'Nutella');
      expect(recent.where((r) => r.food.name['uz'] == 'Nutella'), hasLength(1));
      final keys = {for (final r in recent) r.food.id};
      expect(keys, hasLength(recent.length));
    });
  });

  group('products', () {
    test('label traffic light: food vs drink thresholds', () {
      const cola = Product(
        name: {'uz': 'Cola'},
        kcal: 42,
        sugar: 10.6,
        liquid: true,
      );
      const chips = Product(
        name: {'uz': 'Chips'},
        kcal: 530,
        fat: 33,
        salt: 1.3,
      );
      const water = Product(name: {'uz': 'Suv'}, kcal: 0, liquid: true);
      expect(productFlags(cola), []);
      expect(
        productFlags(
          const Product(name: {'uz': 'x'}, kcal: 46, sugar: 12, liquid: true),
        ),
        [ProductFlag.sugar],
      );
      expect(productFlags(chips), [ProductFlag.fat]);
      expect(productFlags(water), [ProductFlag.light]);
    });

    test('toFood: amount becomes one portion', () {
      const p = Product(
        name: {'uz': 'Rollton'},
        kcal: 449,
        protein: 9.6,
        fat: 19.4,
        carbs: 59.4,
        package: 60,
      );
      final f = p.toFood(60);
      expect(f.source, FoodSource.barcode);
      expect(f.portion, '60 g');
      expect(f.kcal, 269.4);
      expect(f.fat, 11.6);
    });

    test('Open Food Facts page → product (kJ fallback, ml, brand)', () {
      final p = Product.fromOpenFoodFacts('123', {
        'status': 1,
        'product': {
          'product_name': 'Ayran',
          'product_name_ru': 'Айран',
          'brands': 'Musaffo, Other',
          'product_quantity': '500',
          'product_quantity_unit': 'ml',
          'nutriscore_grade': 'b',
          'nutriments': {'energy_100g': 167.36, 'proteins_100g': 1.2},
        },
      })!;
      expect(p.kcal, closeTo(40, 0.01));
      expect(p.liquid, isTrue);
      expect(p.package, 500);
      expect(p.name['ru'], 'Musaffo Айран');
      expect(p.name['uz'], 'Musaffo Ayran');
      expect(p.nutriscore, 'b');
      expect(p.origin, ProductOrigin.internet);
      expect(Product.fromOpenFoodFacts('1', {'status': 0}), isNull);
      expect(
        Product.fromOpenFoodFacts('1', {
          'status': 1,
          'product': {'product_name': 'No kcal', 'nutriments': {}},
        }),
        isNull,
      );
    });

    test('fake: assets by barcode, typed label remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeProductsRepository(
        await SharedPreferences.getInstance(),
      );
      final nutella = await repo.byBarcode('3017620422003');
      expect(nutella?.name['en'], 'Nutella');
      expect(await repo.byBarcode('4780000000001'), isNull);

      const mine = Product(
        barcodes: ['4780000000001'],
        name: {'uz': 'Kurt', 'ru': 'Kurt', 'en': 'Kurt'},
        kcal: 300,
        origin: ProductOrigin.user,
      );
      await repo.remember(mine);
      expect((await repo.byBarcode('4780000000001'))?.kcal, 300);
      expect((await repo.popular()).first.name['uz'], 'Kurt');
    });

    test('online: Open Food Facts once, then from memory', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        expect(req.url.host, 'world.openfoodfacts.org');
        if (req.url.path.contains('000000')) return http.Response('{}', 404);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'status': 1,
              'product': {
                'product_name': 'Qatiq',
                'nutriments': {'energy-kcal_100g': 56},
              },
            }),
          ),
          200,
        );
      });
      final repo = OpenFoodFactsProductsRepository(prefs, client);
      expect((await repo.byBarcode('4780123456789'))?.kcal, 56);
      expect((await repo.byBarcode('4780123456789'))?.kcal, 56);
      expect(calls, 1);
      expect(await repo.byBarcode('4780000000009'), isNull);
      // Nutella is in the assets — no request.
      await repo.byBarcode('3017620422003');
      expect(calls, 2);
    });
  });

  group('photo', () {
    final catalog = [
      for (var i = 0; i < 6; i++)
        Food(
          id: 'f$i',
          name: {'uz': 'Taom $i'},
          kcal: 100.0 * (i + 1),
          portion: '${100 * (i + 1)} g',
        ),
    ];

    test('demo: 3 different guesses, stable for the same photo', () async {
      final demo = DemoFoodVisionRepository(() async => catalog);
      final photo = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final a = await demo.recognize(photo, lang: 'uz');
      final b = await demo.recognize(photo, lang: 'uz');
      expect(a.demo, isTrue);
      expect(a.guesses, hasLength(3));
      expect({for (final g in a.guesses) g.name['uz']}, hasLength(3));
      expect(
        [for (final g in a.guesses) g.name['uz']],
        [for (final g in b.guesses) g.name['uz']],
      );
      expect(a.guesses.first.confidence, 0.62);
    });

    test('guess → food scales nutrients to the grams eaten', () {
      final g = FoodGuess.fromJson({
        'name': {'uz': 'Palov', 'ru': 'Плов', 'en': 'Plov'},
        'emoji': '🍛',
        'grams': 300,
        'kcal': 600,
        'protein': 18,
        'fat': 30,
        'carbs': 64,
        'confidence': 1.7,
      });
      expect(g.confidence, 1);
      final f = g.toFood(150);
      expect(f.source, FoodSource.photo);
      expect(f.portion, '150 g');
      expect(f.kcal, 300);
      expect(f.carbs, 32);
    });
  });

  test('my recipes: newest first, one per name, removable', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    final n = c.read(myRecipesProvider.notifier);
    await n.save(const SavedRecipe(name: 'Osh', text: 'guruch 500 g'));
    await n.save(const SavedRecipe(name: 'Omlet', text: 'tuxum 3 ta'));
    await n.save(
      const SavedRecipe(name: 'osh', text: 'guruch 1 kg', portions: 8),
    );
    expect(
      [for (final r in c.read(myRecipesProvider)) r.name],
      ['osh', 'Omlet'],
    );
    expect(c.read(myRecipesProvider).first.portions, 8);
    await n.remove('Omlet');

    // Survives a restart.
    final c2 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c2.dispose);
    expect(
      [for (final r in c2.read(myRecipesProvider)) r.text],
      ['guruch 1 kg'],
    );
  });
}
