import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/profile/profile_feature.dart';
import 'package:sino/features/profile/presentation/profile_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('profile exposes its root route', () {
    final paths = [for (final r in profileRoutes.whereType<GoRoute>()) r.path];
    expect(paths, contains(AppRoutes.profile));
  });

  testWidgets('profile screen renders stub (fake mode)', (tester) async {
    await pumpScreen(tester, const ProfileScreen());
    expect(find.text('Profil — tez orada'), findsOneWidget);
    expect(find.text('Aziz, 29'), findsOneWidget);
    expect(find.textContaining('Malika'), findsOneWidget);
  });
}
