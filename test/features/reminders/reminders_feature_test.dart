import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/reminders/reminders_feature.dart';
import 'package:sino/features/reminders/presentation/reminders_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('reminders exposes its root route', () {
    final paths = [
      for (final r in remindersRoutes.whereType<GoRoute>()) r.path,
    ];
    expect(paths, contains(AppRoutes.reminders));
  });

  testWidgets('reminders screen renders stub (fake mode)', (tester) async {
    await pumpScreen(tester, const RemindersScreen());
    expect(find.text('Eslatmalar — tez orada'), findsOneWidget);
  });
}
