import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import 'application/doctors_providers.dart';
import 'presentation/appointments_screen.dart';
import 'presentation/doctor_screen.dart';
import 'presentation/doctors_paths.dart';
import 'presentation/doctors_screen.dart';
import 'presentation/labels.dart';

/// The ONLY public file of the `doctors` feature.
final List<RouteBase> doctorsRoutes = [
  GoRoute(
    path: AppRoutes.doctors,
    builder: (context, state) => const DoctorsScreen(),
    routes: [
      // Fixed path before `:id`.
      GoRoute(
        path: 'appointments',
        builder: (context, state) => const AppointmentsScreen(),
      ),
      GoRoute(
        path: ':id',
        builder: (context, state) =>
            DoctorScreen(doctorId: state.pathParameters['id']!),
      ),
    ],
  ),
];

final List<HomeCardSpec> doctorsHomeCards = [
  HomeCardSpec(
    id: 'doctors',
    order: 80,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final next = ref.watch(upcomingAppointmentsProvider).value?.firstOrNull;
        final doctor = next == null
            ? null
            : next.doctor ??
                  ref.watch(doctorsByIdProvider).value?[next.doctorId];
        return ShortcutCard(
          emoji: '🩺',
          title: context.tr(uz: 'Shifokorlar', ru: 'Врачи', en: 'Doctors'),
          subtitle: next == null
              ? context.tr(
                  uz: 'Qabulga yozilish',
                  ru: 'Запись на приём',
                  en: 'Book an appointment',
                )
              : [
                  appointmentWhen(
                    context,
                    next.startsAt,
                    ref.watch(doctorsClockProvider)(),
                  ),
                  if (doctor != null) specialtyLabel(context, doctor.specialty),
                ].join(' · '),
          color: AppColors.sky,
          onTap: () => context.push(
            next == null ? AppRoutes.doctors : DoctorsPaths.appointments,
          ),
        );
      },
    ),
  ),
];
