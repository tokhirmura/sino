import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Shifokor maslahatini almashtirmaydi'), findsNothing);
    expect(find.textContaining('Terapevt'), findsWidgets);
  });
}
