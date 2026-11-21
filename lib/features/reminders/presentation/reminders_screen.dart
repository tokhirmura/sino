import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/reminder_schedule.dart';
import '../application/reminders_providers.dart';
import '../data/models.dart';
import 'labels.dart';
import 'motion.dart';
import 'reminders_paths.dart';
import 'widgets.dart';

/// `/reminders`: gradient header with today's stats, adherence + next
/// dose, today's doses by time, all reminders.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RemindersPaths.create),
        icon: const Icon(Icons.add_alarm_rounded),
        label: Text(context.tr(uz: 'Qo‘shish', ru: 'Добавить', en: 'Add')),
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            const _Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AsyncValueView(
                value: reminders,
                compact: true,
                onRetry: () {
                  ref.invalidate(remindersProvider);
                  ref.invalidate(reminderLogsProvider);
                },
                loading: () => const SkeletonLoader(count: 4),
                data: (list) => list.isEmpty
                    ? EmptyState(
                        emoji: '⏰',
                        title: context.tr(
                          uz: 'Hali eslatma yo‘q',
                          ru: 'Напоминаний пока нет',
                          en: 'No reminders yet',
                        ),
                        message: context.tr(
                          uz:
                              'Dori ichish vaqtini qo‘shing — o‘z vaqtida '
                              'eslatamiz.',
                          ru: 'Добавьте время приёма — мы вовремя напомним.',
                          en: 'Add a medicine time and we’ll remind you.',
                        ),
                        color: AppColors.amber,
                        actionLabel: context.tr(
                          uz: 'Eslatma qo‘shish',
                          ru: 'Добавить напоминание',
                          en: 'Add a reminder',
                        ),
                        actionIcon: Icons.add_alarm_rounded,
                        onAction: () => context.push(RemindersPaths.create),
                      )
                    : _Body(reminders: list),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Title, back / history, and today at a glance: doses taken and active
/// reminders.
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dayOf(DateTime.now());
    final doses = ref.watch(dosesForDayProvider(today)).value;
    final reminders = ref.watch(remindersProvider).value;
    final taken = doses?.where((d) => d.taken).length;
    final active = reminders?.where((r) => r.active).length;
    final canPop = Navigator.of(context).canPop();
    return GradientHeader(
      leading: canPop ? const BackButton(color: Colors.white) : null,
      title: context.tr(uz: 'Eslatmalar', ru: 'Напоминания', en: 'Reminders'),
      subtitle: context.tr(
        uz: 'Dorini o‘z vaqtida iching',
        ru: 'Принимайте лекарства вовремя',
        en: 'Take your medicine on time',
      ),
      trailing: IconButton(
        tooltip: context.tr(
          uz: 'Qabul tarixi',
          ru: 'История приёма',
          en: 'Intake history',
        ),
        onPressed: () => context.push(RemindersPaths.history),
        icon: const Icon(Icons.history_rounded),
      ),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              onDark: true,
              value: doses == null ? '—' : '$taken/${doses.length}',
              label: context.tr(
                uz: 'Bugun ichildi',
                ru: 'Принято сегодня',
                en: 'Taken today',
              ),
              icon: Icons.task_alt_rounded,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: StatTile(
              onDark: true,
              value: active == null ? '—' : '$active',
              label: context.tr(uz: 'Faol', ru: 'Активные', en: 'Active'),
              icon: Icons.alarm_on_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.reminders});

  final List<Reminder> reminders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = dayOf(now);
    final doses = ref.watch(dosesForDayProvider(today));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SummaryCard(),
        const SizedBox(height: 16),
        SectionTitle(context.tr(uz: 'Bugun', ru: 'Сегодня', en: 'Today')),
        const SizedBox(height: 8),
        AsyncValueView(
          value: doses,
          compact: true,
          onRetry: () => ref.invalidate(reminderLogsProvider),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.tr(
                      uz: 'Bugun dori ichish rejalashtirilmagan.',
                      ru: 'Сегодня приёмов нет.',
                      en: 'No doses today.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : Column(
                  children: [
                    for (final (i, d) in list.indexed)
                      DoseTile(
                        key: ValueKey('dose-${d.reminder.id}'),
                        dose: d,
                        now: now,
                        index: i,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        SectionTitle(
          context.tr(
            uz: 'Barcha eslatmalar',
            ru: 'Все напоминания',
            en: 'All reminders',
          ),
        ),
        const SizedBox(height: 8),
        for (final (i, r) in reminders.indexed)
          _ReminderTile(reminder: r).staggerIn(i + 2),
        const SizedBox(height: 8),
        const RemindersDisclaimer(),
      ],
    );
  }
}

/// Adherence over 7 days + the next dose.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final adh = ref.watch(adherenceProvider).value;
    final next = ref.watch(nextDoseProvider).value;
    final percent = adh?.percent;
    final now = DateTime.now();
    return AppCard(
      onTap: () => context.push(RemindersPaths.history),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ProgressRing(
            value: adh?.ratio ?? 0,
            size: 64,
            color: AppColors.good,
            child: Text(
              percent == null ? '—' : '$percent%',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    uz: '7 kunlik intizom',
                    ru: 'Соблюдение за 7 дней',
                    en: '7-day adherence',
                  ),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (adh != null && adh.expected > 0)
                  Text(
                    context.tr(
                      uz: '${adh.expected} dan ${adh.taken} ta doza ichildi',
                      ru: 'Принято ${adh.taken} из ${adh.expected}',
                      en: '${adh.taken} of ${adh.expected} doses taken',
                    ),
                    style: text.bodySmall,
                  ),
                const SizedBox(height: 6),
                Text(
                  next == null
                      ? context.tr(
                          uz: 'Yaqin kunlarda doza yo‘q',
                          ru: 'Ближайших приёмов нет',
                          en: 'No upcoming doses',
                        )
                      : context.tr(
                          uz:
                              'Keyingi: ${_when(context, next.scheduledAt, now)} · '
                              '${next.reminder.name}',
                          ru:
                              'Далее: ${_when(context, next.scheduledAt, now)} · '
                              '${next.reminder.name}',
                          en:
                              'Next: ${_when(context, next.scheduledAt, now)} · '
                              '${next.reminder.name}',
                        ),
                  style: text.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «20:00» today, «ertaga 08:00», «Juma 08:00».
String _when(BuildContext context, DateTime at, DateTime now) {
  final diff = dayOf(at).difference(dayOf(now)).inDays;
  if (diff <= 0) return hhmm(at);
  if (diff == 1) {
    return context.tr(
      uz: 'ertaga ${hhmm(at)}',
      ru: 'завтра ${hhmm(at)}',
      en: 'tomorrow ${hhmm(at)}',
    );
  }
  return '${weekdayShort(context, at.weekday)} ${hhmm(at)}';
}

class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;
    final r = reminder;
    final members = ref.watch(familyMembersProvider).value ?? const [];
    final who = memberName(members, r.memberId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: r.active ? 1 : 0.6,
        child: AppCard(
          animate: false,
          onTap: () => context.push(RemindersPaths.edit(r.id)),
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  reminderTime(r),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        daysLabel(context, r.days),
                        if ((r.dose ?? '').isNotEmpty) r.dose!,
                      ].join(' · '),
                      style: text.bodySmall?.copyWith(color: muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (who != null || !r.active) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (who != null)
                            Tag(
                              who,
                              color: AppColors.violet,
                              icon: Icons.person_rounded,
                            ),
                          if (!r.active)
                            Tag(
                              context.tr(
                                uz: 'To‘xtatilgan',
                                ru: 'На паузе',
                                en: 'Paused',
                              ),
                              color: AppColors.amber,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: r.active,
                onChanged: (v) async {
                  try {
                    await ref
                        .read(remindersProvider.notifier)
                        .setActive(r.id, v);
                  } catch (e) {
                    if (context.mounted) {
                      showRemindersSnack(
                        context,
                        reminderErrorText(context, e),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
