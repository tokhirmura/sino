import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/routing/app_routes.dart';
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
    builder: (context) => ShortcutCard(
      emoji: '❤️',
      title: context.tr(uz: 'Ko‘rsatkichlar', ru: 'Показатели', en: 'Vitals'),
      subtitle: context.tr(
        uz: 'Bosim, puls, qand',
        ru: 'Давление, пульс, сахар',
        en: 'Pressure, pulse, glucose',
      ),
      color: AppColors.coral,
      onTap: () => context.push(AppRoutes.vitals),
    ),
  ),
];
