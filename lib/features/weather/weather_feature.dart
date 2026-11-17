import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/weather_home_card.dart';
import 'presentation/weather_screen.dart';

/// The ONLY public file of the `weather` feature.
final List<RouteBase> weatherRoutes = [
  GoRoute(
    path: AppRoutes.weather,
    builder: (context, state) => const WeatherScreen(),
  ),
];

final List<HomeCardSpec> weatherHomeCards = [
  HomeCardSpec(
    id: 'weather',
    order: 20,
    builder: (context) => const WeatherHomeCard(),
  ),
];
