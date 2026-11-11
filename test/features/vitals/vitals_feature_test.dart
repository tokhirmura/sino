import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/vitals/vitals_feature.dart';
import 'package:sino/features/vitals/presentation/vitals_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('vitals exposes its root route', () {
    final paths = [for (final r in vitalsRoutes.whereType<GoRoute>()) r.path];
    expect(paths, contains(AppRoutes.vitals));
  });

  testWidgets('vitals screen renders stub (fake mode)', (tester) async {
    await pumpScreen(tester, const VitalsScreen());
    expect(find.text('Ko‘rsatkichlar — tez orada'), findsOneWidget);
  });
}
