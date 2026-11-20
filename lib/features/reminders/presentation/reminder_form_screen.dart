import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/storage/prefs.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_title.dart';
import '../application/reminders_providers.dart';
import '../data/models.dart';
import '../data/reminder_notifications.dart';
import 'labels.dart';
import 'widgets.dart';

/// Prefs flag: the notification permission was asked once.
const remindersPermissionAskedKey = 'reminders.permission_asked';

/// `/reminders/new` and `/reminders/:id`: add or edit a reminder.
class ReminderFormScreen extends ConsumerWidget {
  const ReminderFormScreen({super.key, this.reminderId});

  /// `null` — a new reminder.
  final String? reminderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = reminderId;
    final title = id == null
        ? context.tr(
            uz: 'Yangi eslatma',
            ru: 'Новое напоминание',
            en: 'New reminder',
          )
        : context.tr(
            uz: 'Eslatmani tahrirlash',
            ru: 'Изменить напоминание',
            en: 'Edit reminder',
          );
    if (id == null) {
      return AppScaffold(title: title, body: const _Form(initial: null));
    }
    return AppScaffold(
      title: title,
      body: AsyncValueView(
        value: ref.watch(remindersProvider),
        onRetry: () => ref.invalidate(remindersProvider),
        data: (list) {
          final r = list.where((r) => r.id == id).firstOrNull;
          if (r == null) {
            return EmptyState(
              emoji: '🔍',
              title: context.tr(
                uz: 'Eslatma topilmadi',
                ru: 'Напоминание не найдено',
                en: 'Reminder not found',
              ),
            );
          }
          return _Form(key: ValueKey(r.id), initial: r);
        },
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({super.key, required this.initial});

  final Reminder? initial;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _dose = TextEditingController(text: widget.initial?.dose);
  late TimeOfDay _time = widget.initial == null
      ? const TimeOfDay(hour: 8, minute: 0)
      : TimeOfDay(hour: widget.initial!.hour, minute: widget.initial!.minute);
  late Set<int> _days = {...(widget.initial?.days ?? allWeekdays)};
  late String? _memberId = widget.initial?.memberId;
  bool _saving = false;
  String? _nameError;

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null && mounted) setState(() => _time = t);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(
        () => _nameError = context.tr(
          uz: 'Dori nomini kiriting',
          ru: 'Введите название',
          en: 'Enter the name',
        ),
      );
      return;
    }
    if (_days.isEmpty) {
      showRemindersSnack(
        context,
        reminderErrorText(
          context,
          const ReminderException(ReminderProblem.noDays),
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    final notifier = ref.read(remindersProvider.notifier);
    final base =
        widget.initial ?? const Reminder(id: '', name: '', hour: 0, minute: 0);
    final draft = base.copyWith(
      name: name,
      dose: _dose.text.trim(),
      hour: _time.hour,
      minute: _time.minute,
      days: _days.toList(),
      memberId: _memberId,
      clearMember: _memberId == null,
    );
    try {
      if (_editing) {
        await notifier.edit(draft);
      } else {
        await notifier.add(draft);
        await _askPermissionOnce();
      }
      if (!mounted) return;
      showRemindersSnack(
        context,
        context.tr(
          uz: 'Eslatma saqlandi',
          ru: 'Напоминание сохранено',
          en: 'Reminder saved',
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showRemindersSnack(context, reminderErrorText(context, e));
      }
    }
  }

  /// The system notification dialog — once, after the first reminder.
  Future<void> _askPermissionOnce() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(remindersPermissionAskedKey) ?? false) return;
    await prefs.setBool(remindersPermissionAskedKey, true);
    await ref.read(reminderNotificationsProvider).requestPermission();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          ctx.tr(
            uz: 'Eslatmani o‘chirasizmi?',
            ru: 'Удалить напоминание?',
            en: 'Delete the reminder?',
          ),
        ),
        content: Text(
          ctx.tr(
            uz: 'Uning qabul tarixi ham o‘chiriladi.',
            ru: 'История приёма тоже удалится.',
            en: 'Its intake history will be deleted too.',
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
            child: Text(ctx.tr(uz: 'O‘chirish', ru: 'Удалить', en: 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // The optimistic removal unmounts this form — leave the screen first.
    final messenger = ScaffoldMessenger.of(context);
    final deleted = context.tr(
      uz: 'Eslatma o‘chirildi',
      ru: 'Напоминание удалено',
      en: 'Reminder deleted',
    );
    final failed = reminderErrorText(context, Exception());
    final notifier = ref.read(remindersProvider.notifier);
    context.pop();
    try {
      await notifier.remove(widget.initial!.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(deleted)));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  void _preset(List<int> days) => setState(() => _days = {...days});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final members = ref.watch(familyMembersProvider).value ?? const [];
    final timeText = '${two(_time.hour)}:${two(_time.minute)}';
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: context.tr(
              uz: 'Dori nomi',
              ru: 'Лекарство',
              en: 'Medicine',
            ),
            hintText: 'Amlodipin',
            prefixIcon: const Icon(Icons.medication_rounded),
            errorText: _nameError,
          ),
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dose,
          decoration: InputDecoration(
            labelText: context.tr(
              uz: 'Doza (ixtiyoriy)',
              ru: 'Доза (необязательно)',
              en: 'Dose (optional)',
            ),
            hintText: context.tr(
              uz: '1 tabletka, ovqatdan keyin',
              ru: '1 таблетка, после еды',
              en: '1 tablet, after meals',
            ),
            prefixIcon: const Icon(Icons.scale_rounded),
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle(context.tr(uz: 'Vaqt', ru: 'Время', en: 'Time')),
        const SizedBox(height: 8),
        AppCard(
          onTap: _pickTime,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.alarm_rounded, color: AppColors.amber),
              const SizedBox(width: 12),
              Text(
                timeText,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr(uz: 'O‘zgartirish', ru: 'Изменить', en: 'Change'),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            context.tr(
              uz: 'Kuniga bir necha marta — har bir vaqt uchun alohida eslatma.',
              ru: 'Несколько раз в день — отдельное напоминание на каждое время.',
              en: 'Several times a day — one reminder per time.',
            ),
            style: text.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle(context.tr(uz: 'Kunlar', ru: 'Дни', en: 'Days')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in allWeekdays)
              FilterChip(
                label: Text(weekdayShort(context, d)),
                selected: _days.contains(d),
                onSelected: (v) => setState(() {
                  v ? _days.add(d) : _days.remove(d);
                }),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: () => _preset(allWeekdays),
              child: Text(
                context.tr(uz: 'Har kuni', ru: 'Каждый день', en: 'Every day'),
              ),
            ),
            TextButton(
              onPressed: () => _preset(const [1, 2, 3, 4, 5]),
              child: Text(
                context.tr(uz: 'Ish kunlari', ru: 'Будни', en: 'Weekdays'),
              ),
            ),
            TextButton(
              onPressed: () => _preset(const [6, 7]),
              child: Text(
                context.tr(
                  uz: 'Dam olish kunlari',
                  ru: 'Выходные',
                  en: 'Weekends',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionTitle(
          context.tr(uz: 'Kim uchun', ru: 'Для кого', en: 'For whom'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: Text(context.tr(uz: 'O‘zim', ru: 'Для себя', en: 'Me')),
              selected: _memberId == null,
              onSelected: (_) => setState(() => _memberId = null),
            ),
            for (final m in members)
              ChoiceChip(
                label: Text(m.name),
                selected: _memberId == m.id,
                onSelected: (_) => setState(() => _memberId = m.id),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(context.tr(uz: 'Saqlash', ru: 'Сохранить', en: 'Save')),
        ),
        if (_editing) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _saving ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(
              context.tr(uz: 'O‘chirish', ru: 'Удалить', en: 'Delete'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const RemindersDisclaimer(),
      ],
    );
  }
}
