import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/workouts/workouts_feature.dart';
import 'package:sino/features/workouts/presentation/workouts_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('workouts exposes its root route', () {
    final paths = [for (final r in workoutsRoutes.whereType<GoRoute>()) r.path];
    expect(paths, contains(AppRoutes.workouts));
  });

  testWidgets('workouts screen renders stub (fake mode)', (tester) async {
    await pumpScreen(tester, const WorkoutsScreen());
    expect(find.text('Sport — tez orada'), findsOneWidget);
  });
}
