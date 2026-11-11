import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/doctors/doctors_feature.dart';
import 'package:sino/features/doctors/presentation/doctors_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('doctors exposes its root route', () {
    final paths = [for (final r in doctorsRoutes.whereType<GoRoute>()) r.path];
    expect(paths, contains(AppRoutes.doctors));
  });

  testWidgets('doctors screen renders stub (fake mode)', (tester) async {
    await pumpScreen(tester, const DoctorsScreen());
    expect(find.text('Shifokorlar — tez orada'), findsOneWidget);
  });
}
