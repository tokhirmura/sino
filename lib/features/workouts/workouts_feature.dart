import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/workouts_screen.dart';

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
    builder: (context) => ShortcutCard(
      emoji: '🏃',
      title: context.tr(uz: 'Sport', ru: 'Тренировки', en: 'Workouts'),
      subtitle: context.tr(
        uz: 'Bugungi mashg‘ulot',
        ru: 'Тренировка на сегодня',
        en: 'Today’s workout',
      ),
      color: AppColors.violet,
      onTap: () => context.go(AppRoutes.workouts),
    ),
  ),
];
