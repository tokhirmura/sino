import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/doctors_screen.dart';

/// The ONLY public file of the `doctors` feature.
final List<RouteBase> doctorsRoutes = [
  GoRoute(
    path: AppRoutes.doctors,
    builder: (context, state) => const DoctorsScreen(),
  ),
];

final List<HomeCardSpec> doctorsHomeCards = [
  HomeCardSpec(
    id: 'doctors',
    order: 80,
    builder: (context) => ShortcutCard(
      emoji: '🩺',
      title: context.tr(uz: 'Shifokorlar', ru: 'Врачи', en: 'Doctors'),
      subtitle: context.tr(
        uz: 'Qabulga yozilish',
        ru: 'Запись на приём',
        en: 'Book an appointment',
      ),
      color: AppColors.sky,
      onTap: () => context.push(AppRoutes.doctors),
    ),
  ),
];
