import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sino/core/widgets/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/doctors/doctors_feature.dart';
import 'package:sino/features/doctors/presentation/doctors_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('doctors exposes its root route and sub-routes', () {
    final root = doctorsRoutes.whereType<GoRoute>().single;
    expect(root.path, AppRoutes.doctors);
    expect(
      [for (final r in root.routes.whereType<GoRoute>()) r.path],
      ['appointments', ':id'],
    );
  });

  testWidgets('doctors screen lists the catalog (fake mode)', (tester) async {
    await pumpScreen(tester, const DoctorsScreen());
    expect(find.text('Shifokorlar: 16'), findsOneWidget);
    // Rule 13: the catalog carries the disclaimer too.
    expect(find.text('Shifokor maslahatini almashtirmaydi'), findsOneWidget);
    expect(find.textContaining('Terapevt'), findsWidgets);
  });

  testWidgets('doctors: gradient header with search, stats; empty filter', (
    tester,
  ) async {
    await pumpScreen(tester, const DoctorsScreen());
    expect(find.byType(GradientHeader), findsOneWidget);
    expect(find.byType(StatTile), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('Shifokor topilmadi'), findsOneWidget);
    // EmptyState with an action resets the filters.
    await tester.ensureVisible(find.text('Filtrni tozalash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtrni tozalash'));
    await tester.pumpAndSettle();
    expect(find.text('Shifokorlar: 16'), findsOneWidget);
  });
}
