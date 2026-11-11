import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/onboarding_screen.dart';

/// The ONLY public file of the `onboarding` feature.
final List<RouteBase> onboardingRoutes = [
  GoRoute(
    path: AppRoutes.onboarding,
    builder: (context, state) => const OnboardingScreen(),
  ),
];

final List<HomeCardSpec> onboardingHomeCards = const [];
