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

  // Also checks that assets/core/sample_profile_data.json parses (3/8/7).
  // Don't load the asset in another testWidgets of this file: rootBundle
  // caches the future across tests and it never completes in the next one.
  testWidgets('dev mode: hidden until 7 taps on version, then seeds', (
    tester,
  ) async {
    await pumpScreen(tester, const ProfileScreen());
    const seedLabel = 'Namuna ma’lumotlarni yuklash';
    expect(find.text(seedLabel), findsNothing);

    final version = find.textContaining('Sino · v');
    await tester.scrollUntilVisible(version, 200);
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.tap(version);
    }
    await tester.pumpAndSettle();
    expect(find.text(seedLabel), findsNothing);

    await tester.tap(version);
    await tester.pumpAndSettle();
    expect(find.text('Dasturchi rejimi yoqildi'), findsOneWidget);

    final seed = find.text(seedLabel);
    await tester.scrollUntilVisible(seed, 200);
    await tester.pumpAndSettle();
    await tester.tap(seed);
    // Result replaces the «dev mode on» snackbar right away (~0.5 s).
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(
      find.text('Yuklandi: oila — 3, tibbiy karta — 8, tahlillar — 7.'),
      findsOneWidget,
    );
  });
}
