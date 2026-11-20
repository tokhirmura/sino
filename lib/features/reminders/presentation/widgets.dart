import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../application/reminders_providers.dart';
import '../data/models.dart';
import 'labels.dart';

/// Required on every medical screen.
class RemindersDisclaimer extends StatelessWidget {
  const RemindersDisclaimer({super.key});

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
                        'Dozani va qabul vaqtini faqat shifokor belgilaydi. '
                        'Eslatma — faqat yordamchi.',
                    ru:
                        'Не заменяет консультацию врача. Дозу и время приёма '
                        'назначает врач, напоминание — лишь помощник.',
                    en:
                        'Does not replace a doctor’s advice. Your doctor sets '
                        'the dose and schedule; reminders only help.',
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

/// Name of the family member [id] (`null` → `null`, the user).
String? memberName(List<FamilyMember> members, String? id) {
  if (id == null) return null;
  for (final m in members) {
    if (m.id == id) return m.name;
  }
  return null;
}

void showRemindersSnack(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

/// Text of a [ReminderException], or a generic message.
String reminderErrorText(BuildContext context, Object error) {
  if (error is ReminderException) {
    return switch (error.problem) {
      ReminderProblem.emptyName => context.tr(
        uz: 'Dori nomini kiriting.',
        ru: 'Введите название лекарства.',
        en: 'Enter the medicine name.',
      ),
      ReminderProblem.noDays => context.tr(
        uz: 'Kamida bitta kunni tanlang.',
        ru: 'Выберите хотя бы один день.',
        en: 'Pick at least one day.',
      ),
      ReminderProblem.futureDose => context.tr(
        uz: 'Kelajakdagi dozani belgilab bo‘lmaydi.',
        ru: 'Нельзя отметить будущую дозу.',
        en: 'A future dose can’t be marked.',
      ),
    };
  }
  return context.tr(
    uz: 'Saqlab bo‘lmadi. Qayta urinib ko‘ring.',
    ru: 'Не удалось сохранить. Попробуйте ещё раз.',
    en: 'Couldn’t save. Please try again.',
  );
}

/// One dose of a day: time, medicine, dose, person, status and the
/// «Ichdim» / undo button.
class DoseTile extends ConsumerStatefulWidget {
  const DoseTile({super.key, required this.dose, required this.now});

  final Dose dose;
  final DateTime now;

  @override
  ConsumerState<DoseTile> createState() => _DoseTileState();
}

class _DoseTileState extends ConsumerState<DoseTile> {
  bool _busy = false;

  Future<void> _toggle() async {
    final d = widget.dose;
    final logs = ref.read(reminderLogsProvider.notifier);
    setState(() => _busy = true);
    try {
      if (d.log != null) {
        await logs.undo(d.log!.id);
      } else {
        await logs.markTaken(d.reminder, d.scheduledAt);
      }
    } catch (e) {
      if (mounted) showRemindersSnack(context, reminderErrorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;
    final d = widget.dose;
    final r = d.reminder;
    final status = d.status(widget.now);
    final color = doseStatusColor(status);
    final members = ref.watch(familyMembersProvider).value ?? const [];
    final who = memberName(members, r.memberId);
    final takenAt = d.log?.takenAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        color: status == DoseStatus.due ? color.withValues(alpha: 0.10) : null,
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  Text(
                    hhmm(d.scheduledAt),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(doseStatusIcon(status), color: color, size: 20),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((r.dose ?? '').isNotEmpty)
                    Text(
                      r.dose!,
                      style: text.bodySmall?.copyWith(color: muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Tag(doseStatusLabel(context, status), color: color),
                      if (who != null)
                        Tag(
                          who,
                          color: AppColors.violet,
                          icon: Icons.person_rounded,
                        ),
                      if (takenAt != null)
                        Text(
                          context.tr(
                            uz: '${hhmm(takenAt)} da',
                            ru: 'в ${hhmm(takenAt)}',
                            en: 'at ${hhmm(takenAt)}',
                          ),
                          style: text.bodySmall?.copyWith(color: muted),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_busy)
              const SizedBox(
                width: 40,
                height: 40,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (d.log != null)
              IconButton(
                tooltip: context.tr(
                  uz: 'Bekor qilish',
                  ru: 'Отменить',
                  en: 'Undo',
                ),
                onPressed: _toggle,
                icon: const Icon(Icons.undo_rounded),
              )
            else if (status != DoseStatus.upcoming ||
                dayOfDate(d.scheduledAt) == dayOfDate(widget.now))
              FilledButton.tonal(
                onPressed: _toggle,
                style: FilledButton.styleFrom(
                  // The theme makes filled buttons full-width.
                  minimumSize: const Size(0, 40),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  context.tr(uz: 'Ichdim', ru: 'Принял', en: 'Taken'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

DateTime dayOfDate(DateTime d) => DateTime(d.year, d.month, d.day);

/// Like core `Pill`, but the label ellipsizes in narrow cards.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.color = AppColors.primary, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
