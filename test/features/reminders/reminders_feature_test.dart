import 'package:flutter_test/flutter_test.dart';
import 'package:sino/core/widgets/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/reminders/presentation/reminders_screen.dart';
import 'package:sino/features/reminders/reminders_feature.dart';

import '../../helpers/test_app.dart';

void main() {
  test('reminders exposes its root route and sub-routes', () {
    final root = remindersRoutes.whereType<GoRoute>().single;
    expect(root.path, AppRoutes.reminders);
    expect(
      [for (final r in root.routes.whereType<GoRoute>()) r.path],
      ['new', 'history', ':id'],
    );
  });

  testWidgets('reminders screen lists the demo reminders (fake mode)', (
    tester,
  ) async {
    await pumpScreen(tester, const RemindersScreen());
    expect(find.text('Bugun'), findsOneWidget);
    expect(find.text('Barcha eslatmalar'), findsOneWidget);
    expect(find.text('Vitamin D3'), findsWidgets);
  });

  testWidgets('reminders: gradient header with today stats, list animates', (
    tester,
  ) async {
    await pumpScreen(tester, const RemindersScreen());
    expect(find.byType(GradientHeader), findsOneWidget);
    expect(find.byType(StatTile), findsNWidgets(2));
    expect(find.text('Bugun ichildi'), findsOneWidget);
    expect(find.byTooltip('Qabul tarixi'), findsOneWidget);
  });
}
