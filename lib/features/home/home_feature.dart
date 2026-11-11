import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/home_screen.dart';

/// The ONLY public file of the `home` feature.
final List<RouteBase> homeRoutes = [
  GoRoute(
    path: AppRoutes.home,
    builder: (context, state) => const HomeScreen(),
  ),
];

final List<HomeCardSpec> homeHomeCards = const [];
