// Lead-only file. Collects every feature's public contract.
import 'package:go_router/go_router.dart';

import '../core/contracts/home_card.dart';
import '../features/assistant/assistant_feature.dart';
import '../features/doctors/doctors_feature.dart';
import '../features/home/home_feature.dart';
import '../features/nutrition/nutrition_feature.dart';
import '../features/onboarding/onboarding_feature.dart';
import '../features/pharmacy/pharmacy_feature.dart';
import '../features/profile/profile_feature.dart';
import '../features/reminders/reminders_feature.dart';
import '../features/sos/sos_feature.dart';
import '../features/vitals/vitals_feature.dart';
import '../features/weather/weather_feature.dart';
import '../features/workouts/workouts_feature.dart';

/// Routes of each bottom tab, in NavigationBar order:
/// Asosiy, Dorixona, Ovqat, Sport, Profil.
final List<List<RouteBase>> tabBranchRoutes = [
  homeRoutes,
  pharmacyRoutes,
  nutritionRoutes,
  workoutsRoutes,
  profileRoutes,
];

/// Full-screen routes (outside the shell, cover the NavigationBar).
final List<RouteBase> fullscreenRoutes = [
  ...onboardingRoutes,
  ...sosRoutes,
  ...assistantRoutes,
  ...remindersRoutes,
  ...doctorsRoutes,
  ...vitalsRoutes,
  ...weatherRoutes,
];

final List<RouteBase> allRoutes = [
  for (final branch in tabBranchRoutes) ...branch,
  ...fullscreenRoutes,
];

final List<HomeCardSpec> allHomeCards = [
  ...homeHomeCards,
  ...onboardingHomeCards,
  ...profileHomeCards,
  ...sosHomeCards,
  ...assistantHomeCards,
  ...pharmacyHomeCards,
  ...remindersHomeCards,
  ...doctorsHomeCards,
  ...nutritionHomeCards,
  ...workoutsHomeCards,
  ...vitalsHomeCards,
  ...weatherHomeCards,
]..sort((a, b) => a.order.compareTo(b.order));
