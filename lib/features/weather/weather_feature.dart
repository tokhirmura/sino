import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/routing/app_routes.dart';
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
    builder: (context) => ShortcutCard(
      emoji: '🌤️',
      title: context.tr(uz: 'Ob-havo', ru: 'Погода', en: 'Weather'),
      subtitle: context.tr(
        uz: 'Ob-havo va havo sifati',
        ru: 'Погода и качество воздуха',
        en: 'Weather and air quality',
      ),
      color: AppColors.sky,
      onTap: () => context.push(AppRoutes.weather),
    ),
  ),
];
