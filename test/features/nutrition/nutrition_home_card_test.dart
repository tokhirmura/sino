import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/app/app.dart';
import 'package:sino/features/nutrition/application/nutrition_math.dart';
import 'package:sino/features/nutrition/application/nutrition_providers.dart';
import 'package:sino/features/nutrition/presentation/nutrition_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('today’s calories and water; +1 glass; tap opens today', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pumpSinoApp(tester, signedIn: true);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SinoApp)),
    );
    final today = dayOf(DateTime.now());
    final eaten = totalsOf(container.read(dayLogsProvider(today)).value!).kcal
        .round();
    final goal = container.read(kcalGoalProvider).value!;
    expect(eaten, greaterThan(0)); // demo diary of today
    expect(find.text('$eaten / $goal kkal'), findsOneWidget);
    expect(find.text('${goal - eaten} kkal qoldi'), findsOneWidget);

    expect(find.text('3 / 8'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nutrition-home-water-plus')));
    await tester.pumpAndSettle();
    expect(find.text('4 / 8'), findsOneWidget);
    expect(container.read(waterProvider(today)).value, 4);

    // The diary was on another day → the card opens today.
    container.read(selectedDayProvider.notifier).shift(-1);
    await tester.tap(find.byKey(const Key('nutrition-home-kcal')));
    await tester.pumpAndSettle();
    expect(find.byType(NutritionScreen), findsOneWidget);
    expect(find.text('Bugun'), findsOneWidget);
    expect(find.text('4 / 8'), findsOneWidget); // same provider as the tab
  });
}
