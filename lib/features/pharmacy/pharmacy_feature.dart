import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/routing/app_routes.dart';
import 'application/pharmacy_providers.dart';
import 'presentation/home_meds_screen.dart';
import 'presentation/medicine_screen.dart';
import 'presentation/pharmacies_screen.dart';
import 'presentation/pharmacy_paths.dart';
import 'presentation/pharmacy_screen.dart';
import 'presentation/widgets/active_reservation_card.dart';
import 'presentation/widgets/ready_celebration.dart';
import 'presentation/reservations_screen.dart';
import 'presentation/scan_screen.dart';

/// The ONLY public file of the `pharmacy` feature.
final List<RouteBase> pharmacyRoutes = [
  GoRoute(
    path: AppRoutes.pharmacy,
    builder: (context, state) =>
        PharmacyScreen(initialQuery: state.uri.queryParameters['q']),
    routes: [
      GoRoute(
        path: 'medicine/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            MedicineScreen(medicineId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: 'pharmacies',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PharmaciesScreen(),
      ),
      GoRoute(
        path: 'reservations',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReservationsScreen(),
      ),
      GoRoute(
        path: 'home-meds',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const HomeMedsScreen(),
      ),
      GoRoute(
        path: 'scan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ScanScreen(),
      ),
    ],
  ),
];

final List<HomeCardSpec> pharmacyHomeCards = [
  HomeCardSpec(
    id: 'pharmacy',
    order: 40,
    builder: (context) => ReadyCelebrationHost(
      child: Consumer(
        builder: (context, ref, _) {
          final active =
              ref.watch(activeReservationsProvider).value ?? const [];
          if (active.isNotEmpty) {
            // Live 3-step progress of the reservation right on the home.
            return ActiveReservationsCard(
              dense: true,
              title: context.tr(uz: 'Dorixona', ru: 'Аптека', en: 'Pharmacy'),
              onTap: () => context.push(PharmacyPaths.reservations),
            );
          }
          return ShortcutCard(
            emoji: '💊',
            title: context.tr(uz: 'Dorixona', ru: 'Аптека', en: 'Pharmacy'),
            subtitle: context.tr(
              uz: 'Dori qidirish va bron qilish',
              ru: 'Поиск и бронь лекарств',
              en: 'Find and reserve medicines',
            ),
            color: AppColors.primary,
            onTap: () => context.go(AppRoutes.pharmacy),
          );
        },
      ),
    ),
  ),
];
