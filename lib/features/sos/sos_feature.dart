import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/sos_screen.dart';

/// The ONLY public file of the `sos` feature.
final List<RouteBase> sosRoutes = [
  GoRoute(path: AppRoutes.sos, builder: (context, state) => const SosScreen()),
];

final List<HomeCardSpec> sosHomeCards = [
  HomeCardSpec(
    id: 'sos',
    order: 10,
    builder: (context) => ShortcutCard(
      emoji: '🆘',
      title: context.tr(uz: 'SOS', ru: 'SOS', en: 'SOS'),
      subtitle: context.tr(
        uz: 'Tez yordam va yaqinlarga xabar',
        ru: 'Скорая и уведомление близких',
        en: 'Ambulance and alert family',
      ),
      color: AppColors.danger,
      onTap: () => context.push(AppRoutes.sos),
    ),
  ),
];
