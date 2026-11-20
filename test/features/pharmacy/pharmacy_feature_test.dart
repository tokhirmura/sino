import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/pharmacy/pharmacy_feature.dart';
import 'package:sino/features/pharmacy/presentation/pharmacy_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('pharmacy exposes its root route and sub-routes', () {
    final root = pharmacyRoutes.whereType<GoRoute>().single;
    expect(root.path, AppRoutes.pharmacy);
    final subs = [for (final r in root.routes.whereType<GoRoute>()) r.path];
    expect(
      subs,
      containsAll(['medicine/:id', 'pharmacies', 'reservations', 'scan']),
    );
    expect(
      root.routes.whereType<GoRoute>().every(
        (r) => r.parentNavigatorKey == rootNavigatorKey,
      ),
      isTrue,
    );
  });

  testWidgets('pharmacy screen lists the catalog (fake mode)', (tester) async {
    await pumpScreen(tester, const PharmacyScreen());
    expect(find.text('Barcha dorilar'), findsOneWidget);
    expect(find.text('Amlodipin 5 mg'), findsOneWidget);
  });

  testWidgets('/pharmacy?q= passes the query', (tester) async {
    await pumpScreen(tester, const PharmacyScreen(initialQuery: 'Paracetamol'));
    expect(find.widgetWithText(TextField, 'Paracetamol'), findsOneWidget);
    expect(find.text('Natijalar: 5'), findsOneWidget);
    expect(find.text('Paracetamol 500 mg'), findsOneWidget);
    expect(find.text('Amlodipin 5 mg'), findsNothing);
    expect(AppRoutes.pharmacySearch('Paracetamol'), '/pharmacy?q=Paracetamol');
  });
}
