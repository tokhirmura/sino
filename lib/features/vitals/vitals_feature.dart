import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import 'presentation/breathing_screen.dart';
import 'presentation/vitals_home_card.dart';
import 'presentation/vitals_screen.dart';

/// The ONLY public file of the `vitals` feature.
final List<RouteBase> vitalsRoutes = [
  GoRoute(
    path: AppRoutes.vitals,
    builder: (context, state) => const VitalsScreen(),
    routes: [
      GoRoute(
        path: 'breathing',
        builder: (context, state) => const BreathingScreen(),
      ),
    ],
  ),
];

final List<HomeCardSpec> vitalsHomeCards = [
  HomeCardSpec(
    id: 'vitals',
    order: 70,
    builder: (context) => const VitalsHomeCard(),
  ),
  HomeCardSpec(
    id: 'breathing',
    order: 75,
    builder: (context) => ShortcutCard(
      key: const Key('breathing-home-card'),
      emoji: '🌬️',
      title: context.tr(
        uz: '4-7-8 nafas mashqi',
        ru: 'Дыхание 4-7-8',
        en: '4-7-8 breathing',
      ),
      subtitle: context.tr(
        uz: 'Stressni 1 daqiqada pasaytiring',
        ru: 'Снимите стресс за минуту',
        en: 'Ease stress in a minute',
      ),
      color: AppColors.primary,
      onTap: () => context.push(vitalsBreathingPath),
    ),
  ),
];
