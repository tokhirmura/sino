import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/nutrition/nutrition_feature.dart';
import 'package:sino/features/nutrition/presentation/nutrition_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('nutrition exposes its root route', () {
    final paths = [
      for (final r in nutritionRoutes.whereType<GoRoute>()) r.path,
    ];
    expect(paths, contains(AppRoutes.nutrition));
  });

  testWidgets('diary of today: meals, demo logs, ring, water (fake mode)', (
    tester,
  ) async {
    await pumpScreen(tester, const NutritionScreen());

    expect(find.text('Bugun'), findsOneWidget);
    expect(find.text('Nonushta'), findsOneWidget);
    expect(find.text('Tushlik'), findsOneWidget);
    expect(find.text('Lag‘mon'), findsOneWidget);
    expect(find.byKey(const Key('nutrition-kcal-left')), findsOneWidget);
    expect(find.textContaining('Non birligi'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('nutrition-water-plus')),
      200,
    );
    expect(find.text('3 / 8'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nutrition-water-plus')));
    await tester.pumpAndSettle();
    expect(find.text('4 / 8'), findsOneWidget);
    expect(find.byKey(const Key('nutrition-water-hint')), findsOneWidget);
  });

  testWidgets('add food from search, then switch day', (tester) async {
    await pumpScreen(tester, const NutritionScreen());

    await tester.tap(find.byKey(const Key('nutrition-add-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nutrition-meal-chip-dinner')));
    await tester.enterText(
      find.byKey(const Key('nutrition-search-field')),
      'palov',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Palov (osh)'));
    await tester.pumpAndSettle();

    expect(find.text('Palov (osh)'), findsOneWidget);
    expect(
      find.text('Hali hech narsa yo‘q — qo‘shish uchun bosing'),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Oldingi kun'));
    await tester.pumpAndSettle();
    expect(find.text('Kecha'), findsOneWidget);
    expect(find.text('Palov (osh)'), findsOneWidget); // yesterday's demo
    expect(find.text('Lag‘mon'), findsNothing);
  });
}
