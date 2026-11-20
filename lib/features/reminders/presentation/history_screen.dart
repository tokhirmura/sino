import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/reminder_schedule.dart';
import '../application/reminders_providers.dart';
import '../data/models.dart';
import 'labels.dart';
import 'widgets.dart';

/// How many days the history screen shows (the logs cover 30).
const historyScreenDays = 14;

/// `/reminders/history`: per day, each scheduled dose with its log (matched
/// by `reminder_id` + local date of `taken_at`) — taken at what time or
/// missed; a missed dose can still be marked.
class IntakeHistoryScreen extends ConsumerWidget {
  const IntakeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = dayOf(now);
    final both = ref.watch(dosesForDayProvider(today));
    return AppScaffold(
      title: context.tr(
        uz: 'Qabul tarixi',
        ru: 'История приёма',
        en: 'Intake history',
      ),
      padding: EdgeInsets.zero,
      body: AsyncValueView(
        value: both,
        onRetry: () {
          ref.invalidate(remindersProvider);
          ref.invalidate(reminderLogsProvider);
        },
        loading: () => const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: SkeletonList(count: 4),
        ),
        data: (_) {
          final days = <(DateTime, List<Dose>)>[];
          for (var i = 0; i < historyScreenDays; i++) {
            final day = DateTime(today.year, today.month, today.day - i);
            final doses = [
              for (final d
                  in ref.watch(dosesForDayProvider(day)).value ??
                      const <Dose>[])
                if (_counts(d, now)) d,
            ];
            if (doses.isNotEmpty) days.add((day, doses));
          }
          if (days.isEmpty) {
            return EmptyState(
              emoji: '📋',
              title: context.tr(
                uz: 'Tarix hali bo‘sh',
                ru: 'История пока пуста',
                en: 'No history yet',
              ),
              message: context.tr(
                uz: 'Dozani «Ichdim» bilan belgilang — shu yerda ko‘rinadi.',
                ru: 'Отмечайте дозы кнопкой «Принял» — они появятся здесь.',
                en: 'Mark doses as taken and they will show up here.',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const _AdherenceCard(),
              for (final (day, doses) in days) ...[
                const SizedBox(height: 16),
                SectionTitle(
                  dayTitle(context, day, today),
                  trailing: _DayScore(doses: doses, now: now),
                ),
                const SizedBox(height: 8),
                for (final d in doses)
                  DoseTile(
                    key: ValueKey('h-${dateKey(day)}-${d.reminder.id}'),
                    dose: d,
                    now: now,
                  ),
              ],
              const SizedBox(height: 8),
              const RemindersDisclaimer(),
            ],
          );
        },
      ),
    );
  }

  /// Hide doses before the reminder existed (never expected).
  static bool _counts(Dose d, DateTime now) {
    final created = d.reminder.createdAt;
    return d.taken || created == null || !d.scheduledAt.isBefore(created);
  }
}

class _DayScore extends StatelessWidget {
  const _DayScore({required this.doses, required this.now});

  final List<Dose> doses;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final taken = doses.where((d) => d.taken).length;
    final all = doses.length;
    final color = taken == all ? AppColors.good : AppColors.amber;
    return Text(
      '$taken / $all',
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class _AdherenceCard extends ConsumerWidget {
  const _AdherenceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final adh = ref.watch(adherenceProvider).value;
    final percent = adh?.percent;
    final color = percent == null
        ? AppColors.sky
        : percent >= 80
        ? AppColors.good
        : percent >= 50
        ? AppColors.amber
        : AppColors.danger;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            percent == null ? '—' : '$percent%',
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    uz: 'So‘nggi 7 kun',
                    ru: 'Последние 7 дней',
                    en: 'Last 7 days',
                  ),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  adh == null || adh.expected == 0
                      ? context.tr(
                          uz: 'Hali hisoblanadigan doza yo‘q',
                          ru: 'Пока нечего считать',
                          en: 'Nothing to count yet',
                        )
                      : context.tr(
                          uz:
                              '${adh.expected} dan ${adh.taken} ta doza o‘z '
                              'vaqtida belgilandi',
                          ru: 'Принято ${adh.taken} доз из ${adh.expected}',
                          en: '${adh.taken} of ${adh.expected} doses taken',
                        ),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
