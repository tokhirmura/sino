import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/family_care.dart';
import '../data/family_care_repository.dart';
import 'labels.dart';

/// `/family` — «Oila»: a card per family member with today's medicines
/// («1 / 2»), a red alert and «Qoʻngʻiroq qilish» for a dose not marked
/// 30 min after its time, the next doctor visit and an active reservation.
/// At the bottom — what is planned next («Kelajakda»).
class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  @override
  void initState() {
    super.initState();
    // Fresh marks every time the screen opens (doses are marked in
    // «Eslatmalar», another feature).
    Future.microtask(() {
      if (mounted) ref.invalidate(familyCareRawProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final care = ref.watch(familyCareProvider);
    final summary = ref.watch(familySummaryProvider).value;
    void reload() => ref
      ..invalidate(familyMembersProvider)
      ..invalidate(familyCareRawProvider);

    return AppScaffold(
      title: context.tr(uz: 'Oila', ru: 'Семья', en: 'Family'),
      subtitle: summary == null || summary.members == 0
          ? null
          : familySummaryText(context, summary),
      actions: [
        IconButton(
          tooltip: context.tr(
            uz: 'A’zo qo‘shish',
            ru: 'Добавить',
            en: 'Add member',
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          onPressed: () => context.push(AppRoutes.familyMemberNew),
        ),
      ],
      body: AsyncValueView(
        value: care,
        onRetry: reload,
        loading: () => const SkeletonLoader(count: 3, kind: SkeletonKind.card),
        data: (list) => RefreshIndicator(
          onRefresh: () async {
            reload();
            await ref.read(familyCareProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, 24),
            children: [
              if (list.isEmpty)
                EmptyState(
                  emoji: '👨‍👩‍👧',
                  title: context.tr(
                    uz: 'Oila a’zolarini qo‘shing',
                    ru: 'Добавьте близких',
                    en: 'Add your family',
                  ),
                  message: context.tr(
                    uz:
                        'Ularning dorilari, shifokor qabullari va bronlari '
                        'shu yerda ko‘rinadi.',
                    ru: 'Здесь будут их лекарства, приёмы у врача и брони.',
                    en:
                        'Their medicines, doctor visits and reservations '
                        'will show up here.',
                  ),
                  actionLabel: context.tr(
                    uz: 'Qo‘shish',
                    ru: 'Добавить',
                    en: 'Add',
                  ),
                  onAction: () => context.push(AppRoutes.familyMemberNew),
                )
              else
                for (final c in list) ...[
                  MemberCareCard(care: c),
                  const SizedBox(height: AppSpacing.cardGap),
                ],
              const SizedBox(height: AppSpacing.xs),
              const _FutureCard(),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr(
                  uz: 'Shifokor maslahatini almashtirmaydi',
                  ru: 'Не заменяет консультацию врача',
                  en: 'Does not replace medical advice',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «3 kishidan 2 nafari dorini ichdi» (or why not).
String familySummaryText(BuildContext context, FamilySummary s) {
  if (s.withMedicines == 0) {
    return context.tr(
      uz: 'Bugun oilada dori yo‘q',
      ru: 'Сегодня у семьи нет лекарств',
      en: 'No family medicines today',
    );
  }
  return context.tr(
    uz: '${s.withMedicines} kishidan ${s.onTrack} nafari dorini ichdi',
    ru: 'Лекарства вовремя: ${s.onTrack} из ${s.withMedicines}',
    en: '${s.onTrack} of ${s.withMedicines} took their medicines',
  );
}

class MemberCareCard extends ConsumerWidget {
  const MemberCareCard({super.key, required this.care});

  final MemberCare care;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final now = ref.watch(familyClockProvider)();
    final m = care.member;
    final missed = care.missedAt(now);
    final age = m.age;

    return AppCard(
      key: ValueKey('member-${m.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              EmojiBox(
                emoji: relationEmoji(m.relation),
                color: missed.isEmpty ? AppColors.violet : AppColors.garnet,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name, style: text.titleMedium),
                    Text(
                      [
                        relationText(context, m.relation),
                        if (age != null)
                          context.tr(
                            uz: '$age yosh',
                            ru: '$age лет',
                            en: '$age y.o.',
                          ),
                      ].join(' · '),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (care.total > 0)
                ProgressRing(
                  value: care.taken / care.total,
                  size: 52,
                  strokeWidth: 6,
                  color: missed.isEmpty ? AppColors.good : AppColors.garnet,
                  semanticsLabel: context.tr(
                    uz: 'Dorilar: ${care.taken}/${care.total}',
                    ru: 'Лекарства: ${care.taken}/${care.total}',
                    en: 'Medicines: ${care.taken}/${care.total}',
                  ),
                  child: Text(
                    '${care.taken}/${care.total}',
                    key: ValueKey('taken-${m.id}'),
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              IconButton(
                tooltip: context.tr(
                  uz: 'Tahrirlash',
                  ru: 'Изменить',
                  en: 'Edit',
                ),
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => context.push(AppRoutes.familyMember(m.id)),
              ),
            ],
          ),
          if (missed.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MissedAlert(member: m, doses: missed),
          ],
          const SizedBox(height: 12),
          if (care.doses.isEmpty)
            Text(
              context.tr(
                uz: 'Bugun dori yo‘q',
                ru: 'Сегодня лекарств нет',
                en: 'No medicines today',
              ),
              style: text.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final d in care.doses) _DoseRow(dose: d, now: now),
          if (care.visit case final v?) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.event_available_rounded,
              color: AppColors.sky,
              text: _visitText(context, v),
            ),
          ],
          if (care.reservation case final r?) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.shopping_bag_outlined,
              color: AppColors.primary,
              text: [r.medicine, ?r.pharmacy].join(' — '),
              trailing: Pill(
                r.ready
                    ? context.tr(uz: 'Tayyor', ru: 'Готово', en: 'Ready')
                    : context.tr(
                        uz: 'Kutilmoqda',
                        ru: 'Ожидает',
                        en: 'Pending',
                      ),
                color: r.ready ? AppColors.good : AppColors.saffron,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _visitText(BuildContext context, CareVisit v) {
    final when = DateFormat(
      'd MMM, HH:mm',
      Localizations.localeOf(context).toString(),
    ).format(v.startsAt);
    return [
      [?v.specialty, v.doctor].join(' '),
      when,
      if (v.online) context.tr(uz: 'onlayn', ru: 'онлайн', en: 'online'),
    ].join(' · ');
  }
}

class _MissedAlert extends ConsumerWidget {
  const _MissedAlert({required this.member, required this.doses});

  final FamilyMember member;
  final List<CareDose> doses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final ink = AppColors.readable(AppColors.garnet, theme.brightness);
    final phone = member.dialable;

    return Container(
      key: ValueKey('missed-${member.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.garnet.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.20 : 0.09,
        ),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.garnet.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: ink),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      missedText(context, member),
                      style: text.titleSmall?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      [for (final d in doses) '${d.name} · ${hhmm(d.at)}']
                          .join(', '),
                      style: text.bodySmall?.copyWith(color: ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (phone != null)
            FilledButton.icon(
              key: ValueKey('call-${member.id}'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.garnet,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.call_rounded),
              label: Text(
                context.tr(
                  uz: 'Qoʻngʻiroq qilish',
                  ru: 'Позвонить',
                  en: 'Call',
                ),
              ),
              onPressed: () async {
                final ok = await ref.read(dialerProvider)(phone);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(member.phone ?? phone)),
                  );
                }
              },
            )
          else
            OutlinedButton.icon(
              key: ValueKey('add-phone-${member.id}'),
              icon: const Icon(Icons.add_call),
              label: Text(
                context.tr(
                  uz: 'Telefon raqamini qo‘shish',
                  ru: 'Добавить телефон',
                  en: 'Add a phone number',
                ),
              ),
              onPressed: () => context.push(AppRoutes.familyMember(member.id)),
            ),
        ],
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({required this.dose, required this.now});

  final CareDose dose;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final missed = dose.missedAt(now);
    final (icon, color) = dose.taken
        ? (Icons.check_circle_rounded, AppColors.good)
        : missed
        ? (Icons.cancel_rounded, AppColors.garnet)
        : (Icons.schedule_rounded, theme.colorScheme.outline);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              hhmm(dose.at),
              style: text.labelLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              [dose.name, ?dose.dose].join(' · '),
              style: text.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.text,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.readable(color, theme.brightness),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// Honest «what's next»: today relatives are profiles inside one account.
class _FutureCard extends StatelessWidget {
  const _FutureCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget point(String emoji, String body) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, textScaler: TextScaler.noScaling),
          const SizedBox(width: 8),
          Expanded(child: Text(body, style: text.bodyMedium)),
        ],
      ),
    );
    return AppCard(
      key: const ValueKey('family-future'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(uz: 'Kelajakda', ru: 'В планах', en: 'Coming next'),
            style: text.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              uz:
                  'Hozir yaqinlaringiz — sizning hisobingiz ichidagi '
                  'profillar: dorilarni ular uchun siz belgilaysiz.',
              ru:
                  'Сейчас близкие — профили внутри вашего аккаунта: '
                  'приём лекарств отмечаете вы.',
              en:
                  'Today your relatives are profiles inside your account: '
                  'you mark their doses.',
            ),
            style: text.bodySmall,
          ),
          point(
            '🔗',
            context.tr(
              uz:
                  'Havola orqali taklif — onangiz o‘z telefonida dorini '
                  'belgilaydi, siz shu yerda ko‘rasiz.',
              ru:
                  'Приглашение по ссылке — мама отмечает лекарство на своём '
                  'телефоне, а вы видите это здесь.',
              en:
                  'Invite by link — Mom marks her dose on her phone and you '
                  'see it here.',
            ),
          ),
          point(
            '🔔',
            context.tr(
              uz:
                  'Yaqinlarga bildirishnoma: dori ichilmasa, oilaga xabar '
                  'boradi.',
              ru:
                  'Уведомления родным: если лекарство пропущено, семья '
                  'получит сообщение.',
              en: 'Notifications to family: a missed dose alerts the family.',
            ),
          ),
        ],
      ),
    );
  }
}
