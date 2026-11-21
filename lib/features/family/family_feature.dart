import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/family_home_card.dart';
import 'presentation/family_screen.dart';

/// The ONLY public file of the `family` feature.
final List<RouteBase> familyRoutes = [
  GoRoute(
    path: AppRoutes.family,
    builder: (context, state) => const FamilyScreen(),
  ),
];

final List<HomeCardSpec> familyHomeCards = [
  HomeCardSpec(
    id: 'family',
    order: 85,
    builder: (context) => const FamilyHomeCard(),
  ),
];
