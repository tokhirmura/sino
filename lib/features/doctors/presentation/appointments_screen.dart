import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_title.dart';
import '../application/doctors_providers.dart';
import '../data/models.dart';
import 'doctors_paths.dart';
import 'widgets.dart';

/// `/doctors/appointments` — «Mening yozuvlarim»: upcoming and past.
class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(appointmentsProvider);
    return AppScaffold(
      title: context.tr(
        uz: 'Mening yozuvlarim',
        ru: 'Мои записи',
        en: 'My appointments',
      ),
      padding: EdgeInsets.zero,
      body: AsyncValueView(
        value: all,
        onRetry: () => ref.invalidate(appointmentsProvider),
        loading: () => const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: SkeletonList(count: 3, itemHeight: 140),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              emoji: '🗓️',
              title: context.tr(
                uz: 'Hali yozuv yo‘q',
                ru: 'Записей пока нет',
                en: 'No appointments yet',
              ),
              message: context.tr(
                uz: 'Shifokorni tanlang va qulay vaqtga yoziling.',
                ru: 'Выберите врача и удобное время.',
                en: 'Pick a doctor and a convenient time.',
              ),
              color: AppColors.sky,
              action: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => context.pop(),
                child: Text(
                  context.tr(uz: 'Shifokorlar', ru: 'К врачам', en: 'Doctors'),
                ),
              ),
            );
          }
          final upcoming = ref.watch(upcomingAppointmentsProvider).value ?? [];
          final past = ref.watch(pastAppointmentsProvider).value ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (upcoming.isNotEmpty) ...[
                SectionTitle(
                  context.tr(uz: 'Kelgusi', ru: 'Предстоящие', en: 'Upcoming'),
                ),
                const SizedBox(height: 8),
                for (final a in upcoming) _card(context, a),
                const SizedBox(height: 8),
              ],
              if (past.isNotEmpty) ...[
                SectionTitle(
                  context.tr(
                    uz: 'O‘tgan va bekor qilingan',
                    ru: 'Прошедшие и отменённые',
                    en: 'Past and cancelled',
                  ),
                ),
                const SizedBox(height: 8),
                for (final a in past) _card(context, a),
              ],
              const SizedBox(height: 8),
              const DoctorsDisclaimer(),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, Appointment a) => AppointmentCard(
    key: ValueKey(a.id),
    appointment: a,
    onTap: () => context.push(DoctorsPaths.doctor(a.doctorId)),
  );
}
