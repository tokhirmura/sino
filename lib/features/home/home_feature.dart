import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/home_screen.dart';
import 'presentation/report_screen.dart';

/// The ONLY public file of the `home` feature.
final List<RouteBase> homeRoutes = [
  GoRoute(
    path: AppRoutes.home,
    builder: (context, state) => const HomeScreen(),
  ),
];

/// Full-screen routes of the home feature (outside the tab shell).
final List<RouteBase> homeFullscreenRoutes = [
  GoRoute(
    path: AppRoutes.report,
    builder: (context, state) => const ReportScreen(),
  ),
];

final List<HomeCardSpec> homeHomeCards = const [];
