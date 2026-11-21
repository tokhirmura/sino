import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/emoji_box.dart';
import '../../../core/widgets/money.dart';
import '../application/doctors_providers.dart';
import '../data/models.dart';
import 'labels.dart';

/// Required on every medical screen.
class DoctorsDisclaimer extends StatelessWidget {
  const DoctorsDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      elevated: false,
      color: AppColors.amber.withValues(alpha: 0.14),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shifokor maslahatini almashtirmaydi',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr(
                    uz:
                        'Ilova ma’lumot beradi, tashxis qo‘ymaydi. Ahvol '
                        'og‘irlashsa — 103 ga qo‘ng‘iroq qiling.',
                    ru:
                        'Приложение не ставит диагноз. При ухудшении '
                        'состояния звоните 103.',
                    en:
                        'The app does not diagnose. If you feel worse, '
                        'call 103.',
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

String? memberName(List<FamilyMember> members, String? id) {
  if (id == null) return null;
  for (final m in members) {
    if (m.id == id) return m.name;
  }
  return null;
}

void showDoctorsSnack(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

String appointmentErrorText(BuildContext context, Object error) {
  if (error is AppointmentException) {
    return switch (error.problem) {
      AppointmentProblem.slotUnavailable => context.tr(
        uz: 'Bu vaqt band. Boshqa vaqtni tanlang.',
        ru: 'Это время занято. Выберите другое.',
        en: 'This time is taken. Pick another one.',
      ),
      AppointmentProblem.onlineNotSupported => context.tr(
        uz: 'Bu shifokor onlayn qabul qilmaydi.',
        ru: 'Этот врач не принимает онлайн.',
        en: 'This doctor doesn’t consult online.',
      ),
      AppointmentProblem.notCancellable => context.tr(
        uz: 'Bu yozuvni bekor qilib bo‘lmaydi.',
        ru: 'Эту запись нельзя отменить.',
        en: 'This appointment can’t be cancelled.',
      ),
    };
  }
  return context.tr(
    uz: 'Saqlab bo‘lmadi. Qayta urinib ko‘ring.',
    ru: 'Не удалось сохранить. Попробуйте ещё раз.',
    en: 'Couldn’t save. Please try again.',
  );
}

/// «Bepul» or the price.
class DoctorPrice extends StatelessWidget {
  const DoctorPrice({super.key, required this.doctor, this.style});

  final Doctor doctor;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (doctor.isFree) {
      return Text(
        context.tr(uz: 'Bepul', ru: 'Бесплатно', en: 'Free'),
        style: style?.copyWith(
          color: AppColors.readable(
            AppColors.good,
            Theme.of(context).brightness,
          ),
        ),
      );
    }
    final p = doctor.priceUzs;
    if (p == null) return const SizedBox.shrink();
    return Money(p, style: style);
  }
}

/// A catalog row: specialty emoji, name, specialty, clinic, rating, price.
class DoctorTile extends StatelessWidget {
  const DoctorTile({super.key, required this.doctor, required this.onTap});

  final Doctor doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;
    final d = doctor;
    final meta = [
      specialtyLabel(context, d.specialty),
      if (d.years != null) yearsLabel(context, d.years!),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmojiBox(
              emoji: specialtyEmoji(d.specialty),
              color: specialtyColor(d.specialty),
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.name,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    meta,
                    style: text.bodySmall?.copyWith(color: muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (d.clinic != null)
                    Text(
                      d.clinic!,
                      style: text.bodySmall?.copyWith(color: muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (d.rating != null)
                        Tag(
                          d.rating!.toStringAsFixed(1),
                          color: AppColors.amber,
                          icon: Icons.star_rounded,
                        ),
                      if (d.online)
                        Tag(
                          context.tr(uz: 'Onlayn', ru: 'Онлайн', en: 'Online'),
                          color: AppColors.sky,
                          icon: Icons.videocam_rounded,
                        ),
                      DoctorPrice(
                        doctor: d,
                        style: text.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An appointment: doctor, when, person, online / clinic, status, cancel.
class AppointmentCard extends ConsumerStatefulWidget {
  const AppointmentCard({super.key, required this.appointment, this.onTap});

  final Appointment appointment;
  final VoidCallback? onTap;

  @override
  ConsumerState<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends ConsumerState<AppointmentCard> {
  bool _saving = false;

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          ctx.tr(
            uz: 'Yozuvni bekor qilasizmi?',
            ru: 'Отменить запись?',
            en: 'Cancel the appointment?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr(uz: 'Yo‘q', ru: 'Нет', en: 'No')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              ctx.tr(uz: 'Bekor qilish', ru: 'Отменить', en: 'Cancel'),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(appointmentsProvider.notifier)
          .cancel(widget.appointment.id);
    } catch (e) {
      if (mounted) showDoctorsSnack(context, appointmentErrorText(context, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;
    final a = widget.appointment;
    final d = a.doctor ?? ref.watch(doctorsByIdProvider).value?[a.doctorId];
    final now = ref.watch(doctorsClockProvider)();
    final members = ref.watch(familyMembersProvider).value ?? const [];
    final who = memberName(members, a.memberId);
    final color = appointmentStatusColor(a, now);
    final cancelled = a.status == AppointmentStatus.cancelled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: cancelled ? 0.6 : 1,
        child: AppCard(
          onTap: widget.onTap,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  EmojiBox(
                    emoji: specialtyEmoji(d?.specialty ?? ''),
                    color: specialtyColor(d?.specialty ?? ''),
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d?.name ?? '—',
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (d != null)
                          Text(
                            specialtyLabel(context, d.specialty),
                            style: text.bodySmall?.copyWith(color: muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      appointmentWhen(context, a.startsAt, now),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Tag(appointmentStatusLabel(context, a, now), color: color),
                  Tag(
                    a.online
                        ? context.tr(uz: 'Onlayn', ru: 'Онлайн', en: 'Online')
                        : context.tr(
                            uz: 'Klinikada',
                            ru: 'В клинике',
                            en: 'In clinic',
                          ),
                    color: a.online ? AppColors.sky : AppColors.primary,
                    icon: a.online
                        ? Icons.videocam_rounded
                        : Icons.local_hospital_rounded,
                  ),
                  if (who != null)
                    Tag(
                      who,
                      color: AppColors.violet,
                      icon: Icons.person_rounded,
                    ),
                ],
              ),
              if (!a.online && d?.clinic != null && !cancelled) ...[
                const SizedBox(height: 6),
                Text(d!.clinic!, style: text.bodySmall?.copyWith(color: muted)),
              ],
              if (a.isUpcoming(now)) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _saving
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                          onPressed: _cancel,
                          child: Text(
                            context.tr(
                              uz: 'Bekor qilish',
                              ru: 'Отменить',
                              en: 'Cancel',
                            ),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Like core `Pill` (readable ink on a tinted background), but the label
/// ellipsizes — never overflows in narrow cards or wraps.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.color = AppColors.primary, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    // Text / icon darkened (light) or lightened (dark) to contrast ≥ 4.5.
    final ink = AppColors.readable(color, brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      // The icon is dropped only when there is no room even for it.
      child: LayoutBuilder(
        builder: (context, box) {
          final withIcon = icon != null && box.maxWidth >= 40;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (withIcon) ...[
                Icon(icon, size: 14, color: ink),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ink,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
