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

  testWidgets('nutrition screen renders stub (fake mode)', (tester) async {
    await pumpScreen(tester, const NutritionScreen());
    expect(find.text('Ovqat — tez orada'), findsOneWidget);
  });
}
