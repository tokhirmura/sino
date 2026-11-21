import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../application/nutrition_math.dart';
import '../../application/nutrition_providers.dart';
import '../../application/water_reminders.dart';
import '../../data/models.dart';

/// 8 glasses of water for [day]: tap a glass to set the count, ± buttons,
/// one-line hint about the day's balance; the bell turns the reminders
/// every 2 hours (9:00–21:00) on and off (S2-7).
class WaterCard extends ConsumerStatefulWidget {
  const WaterCard({super.key, required this.day});

  final DateTime day;

  @override
  ConsumerState<WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends ConsumerState<WaterCard> {
  @override
  void initState() {
    super.initState();
    // Reminders are on by default: ask for notifications once, schedule.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(waterRemindersProvider.notifier)
            .askOnce()
            .catchError((Object _) {}),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final provider = waterProvider(day);
    return AsyncValueView(
      value: ref.watch(provider),
      compact: true,
      onRetry: () => ref.invalidate(provider),
      data: (glasses) => _WaterBody(
        day: day,
        glasses: glasses,
        onSet: (v) async {
          try {
            await ref.read(provider.notifier).set(v);
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
          }
        },
      ),
    );
  }
}

class _WaterBody extends StatelessWidget {
  const _WaterBody({
    required this.day,
    required this.glasses,
    required this.onSet,
  });

  final DateTime day;
  final int glasses;
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context) {
    const goal = WaterLog.goal;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final hint = waterHint(glasses: glasses, day: day, now: DateTime.now());
    final ml = glasses * 250;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('💧', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(uz: 'Suv', ru: 'Вода', en: 'Water'),
                  style: text.titleMedium,
                ),
              ),
              Text(
                '$glasses / $goal',
                key: const Key('nutrition-water-count'),
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.sky,
                ),
              ),
              Text(
                '  · ${(ml / 1000).toStringAsFixed(ml % 1000 == 0 ? 0 : 2)} '
                '${context.tr(uz: 'l', ru: 'л', en: 'L')}',
                style: text.bodySmall,
              ),
              const _ReminderBell(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < goal; i++)
                _Glass(
                  index: i,
                  filled: i < glasses,
                  // Tapping the last filled glass empties it.
                  onTap: () => onSet(i + 1 == glasses ? i : i + 1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _HintText(hint: hint)),
              IconButton.filledTonal(
                key: const Key('nutrition-water-minus'),
                tooltip: context.tr(
                  uz: 'Bir stakan kamaytirish',
                  ru: 'Убрать стакан',
                  en: 'Remove a glass',
                ),
                onPressed: glasses > 0 ? () => onSet(glasses - 1) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                key: const Key('nutrition-water-plus'),
                tooltip: context.tr(
                  uz: 'Bir stakan qo‘shish',
                  ru: 'Добавить стакан',
                  en: 'Add a glass',
                ),
                style: IconButton.styleFrom(backgroundColor: AppColors.sky),
                onPressed: glasses < maxWaterGlasses
                    ? () => onSet(glasses + 1)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({
    required this.index,
    required this.filled,
    required this.onTap,
  });

  final int index;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: context.tr(
        uz: '${index + 1}-stakan',
        ru: 'Стакан ${index + 1}',
        en: 'Glass ${index + 1}',
      ),
      selected: filled,
      child: InkResponse(
        key: Key('nutrition-glass-$index'),
        onTap: onTap,
        radius: 22,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 30,
          height: 38,
          decoration: BoxDecoration(
            color: filled
                ? AppColors.sky
                : AppColors.sky.withValues(alpha: isDark ? 0.18 : 0.12),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
              bottom: Radius.circular(10),
            ),
          ),
          child: Icon(
            Icons.water_drop_rounded,
            size: 16,
            color: filled ? Colors.white : AppColors.sky.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText({required this.hint});

  final WaterHint hint;

  @override
  Widget build(BuildContext context) {
    final n = hint.missing;
    final (msg, color) = switch (hint.status) {
      WaterStatus.done => (
        context.tr(
          uz: 'Barakalla! Kunlik me’yor bajarildi 🎉',
          ru: 'Отлично! Норма на день выполнена 🎉',
          en: 'Great! Daily goal reached 🎉',
        ),
        AppColors.good,
      ),
      WaterStatus.onTrack => (
        context.tr(
          uz: 'Yaxshi sur’at — shunday davom eting',
          ru: 'Хороший темп — так держать',
          en: 'Good pace — keep it up',
        ),
        AppColors.primary,
      ),
      WaterStatus.behind => (
        context.tr(
          uz: 'Ortda qolyapsiz: hozir $n stakan iching',
          ru: 'Вы отстаёте: выпейте сейчас $n стак.',
          en: 'Falling behind: drink $n glasses now',
        ),
        AppColors.amber,
      ),
      WaterStatus.missed => (
        context.tr(
          uz: 'Me’yorga $n stakan yetmagan',
          ru: 'До нормы не хватило $n стак.',
          en: '$n glasses short of the goal',
        ),
        AppColors.coral,
      ),
    };
    return Text(
      msg,
      key: const Key('nutrition-water-hint'),
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
    );
  }
}

/// Water reminders on / off; a SnackBar says what changed.
class _ReminderBell extends ConsumerWidget {
  const _ReminderBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(waterRemindersProvider);
    final hours =
        '${waterReminderHours.first}:00–${waterReminderHours.last}:00';
    return IconButton(
      key: const Key('nutrition-water-notify'),
      visualDensity: VisualDensity.compact,
      tooltip: on
          ? context.tr(
              uz: 'Suv eslatmalarini o‘chirish',
              ru: 'Выключить напоминания о воде',
              en: 'Turn water reminders off',
            )
          : context.tr(
              uz: 'Suv eslatmalarini yoqish',
              ru: 'Включить напоминания о воде',
              en: 'Turn water reminders on',
            ),
      isSelected: on,
      color: AppColors.sky,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final msg = (
          on: context.tr(
            uz: 'Suv eslatmalari yoqildi: har 2 soatda, $hours',
            ru: 'Напоминания о воде включены: каждые 2 ч, $hours',
            en: 'Water reminders on: every 2 hours, $hours',
          ),
          off: context.tr(
            uz: 'Suv eslatmalari o‘chirildi',
            ru: 'Напоминания о воде выключены',
            en: 'Water reminders off',
          ),
          denied: context.tr(
            uz:
                'Bildirishnomalarga ruxsat yo‘q — telefon sozlamalarida '
                'Sino uchun yoqing',
            ru: 'Уведомления запрещены — включите их для Sino в настройках',
            en: 'Notifications are off — allow them for Sino in Settings',
          ),
        );
        final granted = await ref
            .read(waterRemindersProvider.notifier)
            .setEnabled(!on);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                on
                    ? msg.off
                    : granted
                    ? msg.on
                    : msg.denied,
              ),
            ),
          );
      },
      selectedIcon: const Icon(Icons.notifications_active_rounded),
      icon: const Icon(Icons.notifications_off_outlined),
    );
  }
}
