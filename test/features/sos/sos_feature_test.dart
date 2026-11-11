import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/sos/sos_feature.dart';
import 'package:sino/features/sos/presentation/sos_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('sos exposes its root route', () {
    final paths = [for (final r in sosRoutes.whereType<GoRoute>()) r.path];
    expect(paths, contains(AppRoutes.sos));
  });

  testWidgets('sos screen renders stub (fake mode)', (tester) async {
    await pumpScreen(tester, const SosScreen());
    expect(find.text('SOS — tez orada'), findsOneWidget);
  });
}
