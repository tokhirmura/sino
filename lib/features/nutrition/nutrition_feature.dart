import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/nutrition_screen.dart';
import 'presentation/widgets/nutrition_home_card.dart';

/// The ONLY public file of the `nutrition` feature.
final List<RouteBase> nutritionRoutes = [
  GoRoute(
    path: AppRoutes.nutrition,
    builder: (context, state) => const NutritionScreen(),
  ),
];

final List<HomeCardSpec> nutritionHomeCards = [
  HomeCardSpec(
    id: 'nutrition',
    order: 50,
    builder: (context) => const NutritionHomeCard(),
  ),
];
