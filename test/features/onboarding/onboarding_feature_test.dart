import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/onboarding/onboarding_feature.dart';
import 'package:sino/features/onboarding/presentation/onboarding_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('onboarding exposes its root route', () {
    final paths = [
      for (final r in onboardingRoutes.whereType<GoRoute>()) r.path,
    ];
    expect(paths, contains(AppRoutes.onboarding));
  });

  testWidgets('onboarding screen renders stub (fake mode)', (tester) async {
    await pumpScreen(tester, const OnboardingScreen());
    expect(find.text('Xush kelibsiz — tez orada'), findsOneWidget);
  });
}
