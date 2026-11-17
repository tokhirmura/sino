import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/workouts_screen.dart';
import 'presentation/widgets/workouts_home_card.dart';

/// The ONLY public file of the `workouts` feature.
final List<RouteBase> workoutsRoutes = [
  GoRoute(
    path: AppRoutes.workouts,
    builder: (context, state) => const WorkoutsScreen(),
  ),
];

final List<HomeCardSpec> workoutsHomeCards = [
  HomeCardSpec(
    id: 'workouts',
    order: 60,
    builder: (context) => const WorkoutsHomeCard(),
  ),
];
