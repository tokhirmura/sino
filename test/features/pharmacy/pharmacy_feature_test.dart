import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/pharmacy/pharmacy_feature.dart';
import 'package:sino/features/pharmacy/presentation/pharmacy_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('pharmacy exposes its root route', () {
    final paths = [for (final r in pharmacyRoutes.whereType<GoRoute>()) r.path];
    expect(paths, contains(AppRoutes.pharmacy));
  });

  testWidgets('pharmacy screen renders stub (fake mode)', (tester) async {
    await pumpScreen(tester, const PharmacyScreen());
    expect(find.text('Dorixona — tez orada'), findsOneWidget);
  });

  testWidgets('/pharmacy?q= passes the query', (tester) async {
    await pumpScreen(tester, const PharmacyScreen(initialQuery: 'Paracetamol'));
    expect(find.text('Qidiruv: Paracetamol'), findsOneWidget);
    expect(AppRoutes.pharmacySearch('Paracetamol'), '/pharmacy?q=Paracetamol');
  });
}
