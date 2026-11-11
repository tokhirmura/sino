import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/reminders_screen.dart';

/// The ONLY public file of the `reminders` feature.
final List<RouteBase> remindersRoutes = [
  GoRoute(
    path: AppRoutes.reminders,
    builder: (context, state) => const RemindersScreen(),
  ),
];

final List<HomeCardSpec> remindersHomeCards = [
  HomeCardSpec(
    id: 'reminders',
    order: 30,
    builder: (context) => ShortcutCard(
      emoji: '⏰',
      title: context.tr(uz: 'Eslatmalar', ru: 'Напоминания', en: 'Reminders'),
      subtitle: context.tr(
        uz: 'Dori ichish vaqti',
        ru: 'Время приёма лекарств',
        en: 'Medication schedule',
      ),
      color: AppColors.amber,
      onTap: () => context.push(AppRoutes.reminders),
    ),
  ),
];
