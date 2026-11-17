import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/vitals_home_card.dart';
import 'presentation/vitals_screen.dart';

/// The ONLY public file of the `vitals` feature.
final List<RouteBase> vitalsRoutes = [
  GoRoute(
    path: AppRoutes.vitals,
    builder: (context, state) => const VitalsScreen(),
  ),
];

final List<HomeCardSpec> vitalsHomeCards = [
  HomeCardSpec(
    id: 'vitals',
    order: 70,
    builder: (context) => const VitalsHomeCard(),
  ),
];
