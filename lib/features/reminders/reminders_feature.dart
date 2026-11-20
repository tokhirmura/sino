import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import 'application/reminder_schedule.dart';
import 'application/reminders_providers.dart';
import 'data/models.dart';
import 'presentation/history_screen.dart';
import 'presentation/labels.dart';
import 'presentation/reminder_form_screen.dart';
import 'presentation/reminders_screen.dart';

/// The ONLY public file of the `reminders` feature.
final List<RouteBase> remindersRoutes = [
  GoRoute(
    path: AppRoutes.reminders,
    builder: (context, state) => const RemindersScreen(),
    routes: [
      // Fixed paths before `:id`.
      GoRoute(
        path: 'new',
        builder: (context, state) => const ReminderFormScreen(),
      ),
      GoRoute(
        path: 'history',
        builder: (context, state) => const IntakeHistoryScreen(),
      ),
      GoRoute(
        path: ':id',
        builder: (context, state) =>
            ReminderFormScreen(reminderId: state.pathParameters['id']),
      ),
    ],
  ),
];

final List<HomeCardSpec> remindersHomeCards = [
  HomeCardSpec(
    id: 'reminders',
    order: 30,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final next = ref.watch(nextDoseProvider).value;
        final now = DateTime.now();
        final due = next != null && next.status(now) == DoseStatus.due;
        final subtitle = next == null
            ? context.tr(
                uz: 'Dori ichish vaqti',
                ru: 'Время приёма лекарств',
                en: 'Medication schedule',
              )
            : due
            ? context.tr(
                uz: 'Hozir: ${next.reminder.name}',
                ru: 'Пора: ${next.reminder.name}',
                en: 'Now: ${next.reminder.name}',
              )
            : dayOf(next.scheduledAt) == dayOf(now)
            ? context.tr(
                uz: 'Keyingi: ${hhmm(next.scheduledAt)} · ${next.reminder.name}',
                ru: 'Далее: ${hhmm(next.scheduledAt)} · ${next.reminder.name}',
                en: 'Next: ${hhmm(next.scheduledAt)} · ${next.reminder.name}',
              )
            : context.tr(
                uz: 'Keyingi: ertaga ${hhmm(next.scheduledAt)}',
                ru: 'Далее: завтра ${hhmm(next.scheduledAt)}',
                en: 'Next: tomorrow ${hhmm(next.scheduledAt)}',
              );
        return ShortcutCard(
          emoji: '⏰',
          title: context.tr(
            uz: 'Eslatmalar',
            ru: 'Напоминания',
            en: 'Reminders',
          ),
          subtitle: subtitle,
          color: due ? AppColors.coral : AppColors.amber,
          onTap: () => context.push(AppRoutes.reminders),
        );
      },
    ),
  ),
];
