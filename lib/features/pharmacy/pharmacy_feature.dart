import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/pharmacy_screen.dart';

/// The ONLY public file of the `pharmacy` feature.
final List<RouteBase> pharmacyRoutes = [
  GoRoute(
    path: AppRoutes.pharmacy,
    builder: (context, state) =>
        PharmacyScreen(initialQuery: state.uri.queryParameters['q']),
  ),
];

final List<HomeCardSpec> pharmacyHomeCards = [
  HomeCardSpec(
    id: 'pharmacy',
    order: 40,
    builder: (context) => ShortcutCard(
      emoji: '💊',
      title: context.tr(uz: 'Dorixona', ru: 'Аптека', en: 'Pharmacy'),
      subtitle: context.tr(
        uz: 'Dori qidirish va bron qilish',
        ru: 'Поиск и бронь лекарств',
        en: 'Find and reserve medicines',
      ),
      color: AppColors.primary,
      onTap: () => context.go(AppRoutes.pharmacy),
    ),
  ),
];
