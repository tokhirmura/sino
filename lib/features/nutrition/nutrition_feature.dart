import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/nutrition_screen.dart';

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
    builder: (context) => ShortcutCard(
      emoji: '🥗',
      title: context.tr(uz: 'Ovqat', ru: 'Питание', en: 'Nutrition'),
      subtitle: context.tr(
        uz: 'Kaloriya va suv',
        ru: 'Калории и вода',
        en: 'Calories and water',
      ),
      color: AppColors.good,
      onTap: () => context.go(AppRoutes.nutrition),
    ),
  ),
];
