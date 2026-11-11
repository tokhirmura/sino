import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/profile_screen.dart';

/// The ONLY public file of the `profile` feature.
final List<RouteBase> profileRoutes = [
  GoRoute(
    path: AppRoutes.profile,
    builder: (context, state) => const ProfileScreen(),
  ),
];

final List<HomeCardSpec> profileHomeCards = const [];
