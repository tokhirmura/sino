import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/vitals_math.dart';
import '../application/vitals_providers.dart';
import '../data/models.dart';
import 'breathing_screen.dart';
import 'labels.dart';
import 'widgets/add_vital_sheet.dart';
import 'widgets/bmi_card.dart';
import 'widgets/vital_chart.dart';

/// Vitals: tiles with the latest value of each kind, a 7-day chart of the
/// selected kind with its general range, the week's entries, BMI.
/// Tapping «Oxirgi 7 kun» 5 times unlocks the developer «test history».
class VitalsScreen extends ConsumerWidget {
  const VitalsScreen({super.key});

  static void _snack(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(vitalsWeekAllProvider);
    final kind = ref.watch(selectedVitalKindProvider);

    Future<void> add() async {
      final v = await showAddVitalSheet(context, kind);
      if (v == null || !context.mounted) return;
      try {
        await ref
            .read(vitalsActionsProvider)
            .add(kind: v.kind, value: v.value, value2: v.value2);
        ref.read(selectedVitalKindProvider.notifier).select(v.kind);
        if (context.mounted) {
          _snack(
            context,
            context.tr(uz: 'Saqlandi', ru: 'Сохранено', en: 'Saved'),
          );
        }
      } catch (e) {
        if (context.mounted) _snack(context, errorMessage(context, e));
      }
    }

    return AppScaffold(
      title: context.tr(
        uz: 'Sog‘liq ko‘rsatkichlari',
        ru: 'Показатели здоровья',
        en: 'Health vitals',
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('vitals-add-fab'),
        onPressed: add,
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr(uz: 'Qo‘shish', ru: 'Добавить', en: 'Add')),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vitalsWeekAllProvider);
          await ref
              .read(vitalsWeekAllProvider.future)
              .catchError((Object _) => <Vital>[]);
        },
        child: AsyncValueView(
          value: week,
          onRetry: () => ref.invalidate(vitalsWeekAllProvider),
          loading: () =>
              const SkeletonLoader(count: 6, kind: SkeletonKind.grid),
          data: (list) => _Body(list: list, kind: kind, onAdd: add),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.list, required this.kind, required this.onAdd});

  final List<Vital> list;
  final VitalKind kind;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final text = Theme.of(context).textTheme;
    final dev = ref.watch(vitalsDevModeProvider);
    final user = ref.watch(currentUserProvider).value;
    Vital? latest(VitalKind k) {
      for (final v in list) {
        if (v.kind == k) return v;
      }
      return null;
    }

    final ofKind = [
      for (final v in list)
        if (v.kind == kind) v,
    ];

    Future<void> remove(Vital v) async {
      final actions = ref.read(vitalsActionsProvider);
      try {
        await actions.remove(v.id);
        if (!context.mounted) return;
        VitalsScreen._snack(
          context,
          context.tr(uz: 'O‘chirildi', ru: 'Удалено', en: 'Removed'),
          action: SnackBarAction(
            label: context.tr(uz: 'Qaytarish', ru: 'Вернуть', en: 'Undo'),
            onPressed: () => actions.add(
              kind: v.kind,
              value: v.value,
              value2: v.value2,
              measuredAt: v.measuredAt,
            ),
          ),
        );
      } catch (e) {
        if (context.mounted) {
          VitalsScreen._snack(context, errorMessage(context, e));
        }
      }
    }

    Future<void> fill() async {
      try {
        final n = await ref.read(vitalsActionsProvider).fillTestHistory();
        if (!context.mounted) return;
        VitalsScreen._snack(
          context,
          n == 0
              ? context.tr(
                  uz: 'Hafta allaqachon to‘liq',
                  ru: 'Неделя уже заполнена',
                  en: 'The week is already full',
                )
              : context.tr(
                  uz: '$n ta test o‘lchovi qo‘shildi',
                  ru: 'Добавлено тестовых измерений: $n',
                  en: '$n test measurements added',
                ),
        );
      } catch (e) {
        if (context.mounted) {
          VitalsScreen._snack(context, errorMessage(context, e));
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _SecretHeader(now: now),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final k in VitalKind.values)
              _KindTile(
                kind: k,
                latest: latest(k),
                selected: k == kind,
                onTap: () =>
                    ref.read(selectedVitalKindProvider.notifier).select(k),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(kind.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kind.label(context),
                      key: const Key('vitals-chart-title'),
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(kind.unitText(context), style: text.bodySmall),
                ],
              ),
              if (kind.normText() != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    context.tr(
                      uz: 'Umumiy me’yor: ${kind.normText()}',
                      ru: 'Общий ориентир: ${kind.normText()}',
                      en: 'General range: ${kind.normText()}',
                    ),
                    style: text.bodySmall,
                  ),
                ),
              const SizedBox(height: 8),
              VitalChart(kind: kind, points: weekSeries(list, kind, now)),
            ],
          ),
        ),
        SectionTitle(
          context.tr(
            uz: 'Bu haftadagi o‘lchovlar',
            ru: 'Измерения за неделю',
            en: 'This week’s measurements',
          ),
        ),
        if (ofKind.isEmpty)
          EmptyState(
            key: const Key('vitals-empty'),
            emoji: kind.emoji,
            color: kind.color,
            title: context.tr(
              uz: 'Bu hafta o‘lchov yo‘q',
              ru: 'За неделю измерений нет',
              en: 'No measurements this week',
            ),
            message: context.tr(
              uz: '«${kind.label(context)}» ni kiriting — grafik o‘zi chiziladi.',
              ru: 'Внесите «${kind.label(context)}» — график построится сам.',
              en: 'Log “${kind.label(context)}” — the chart draws itself.',
            ),
            actionLabel: context.tr(
              uz: 'O‘lchov qo‘shish',
              ru: 'Добавить измерение',
              en: 'Add a measurement',
            ),
            actionIcon: Icons.add_rounded,
            onAction: onAdd,
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final v in ofKind.take(14))
                  ListTile(
                    key: Key('vitals-entry-${v.id}'),
                    dense: true,
                    title: Text(
                      '${vitalValueText(v)} ${kind.unitText(context)}',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(whenText(context, v.measuredAt, now)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (kind != VitalKind.weight)
                          Pill(
                            statusText(context, kind, v.status),
                            color: statusColor(v.status),
                          ),
                        IconButton(
                          tooltip: context.tr(
                            uz: 'O‘chirish',
                            ru: 'Удалить',
                            en: 'Remove',
                          ),
                          onPressed: () => remove(v),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        BmiCard(
          heightCm: user?.heightCm,
          weightKg: latest(VitalKind.weight)?.value ?? user?.weightKg,
        ),
        const SizedBox(height: 16),
        ShortcutCard(
          key: const Key('vitals-breathing'),
          emoji: '🌬️',
          title: context.tr(
            uz: '4-7-8 nafas mashqi',
            ru: 'Дыхание 4-7-8',
            en: '4-7-8 breathing',
          ),
          subtitle: context.tr(
            uz: '1 daqiqada tinchlaning — bosim va uyqu uchun foydali',
            ru: 'Успокойтесь за минуту — полезно для давления и сна',
            en: 'Calm down in a minute — good for blood pressure and sleep',
          ),
          color: AppColors.primary,
          onTap: () => context.push(vitalsBreathingPath),
        ),
        if (dev) ...[
          const SizedBox(height: 16),
          AppCard(
            key: const Key('vitals-dev'),
            elevated: false,
            color: AppColors.violet.withValues(alpha: 0.10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr(
                    uz: '🧪 Dasturchi rejimi',
                    ru: '🧪 Режим разработчика',
                    en: '🧪 Developer mode',
                  ),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  key: const Key('vitals-fill'),
                  onPressed: fill,
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: Text(
                    context.tr(
                      uz: 'Test tarixini to‘ldirish (7 kun)',
                      ru: 'Заполнить тестовой историей (7 дней)',
                      en: 'Fill test history (7 days)',
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('vitals-dev-off'),
                  onPressed: () =>
                      ref.read(vitalsDevModeProvider.notifier).set(false),
                  child: Text(
                    context.tr(
                      uz: 'Dasturchi rejimini o‘chirish',
                      ru: 'Выключить режим разработчика',
                      en: 'Turn off developer mode',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          context.tr(
            uz:
                'Me’yorlar kattalar uchun umumiy ko‘rsatkich, tashxis emas. '
                'Shifokor maslahatini almashtirmaydi.',
            ru:
                'Нормы — общие ориентиры для взрослых, не диагноз. '
                'Не заменяет консультацию врача.',
            en:
                'Ranges are general adult reference points, not a diagnosis. '
                'Does not replace a doctor’s advice.',
          ),
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }
}

/// «Oxirgi 7 kun» — 5 quick taps unlock developer mode.
class _SecretHeader extends ConsumerStatefulWidget {
  const _SecretHeader({required this.now});

  final DateTime now;

  @override
  ConsumerState<_SecretHeader> createState() => _SecretHeaderState();
}

class _SecretHeaderState extends ConsumerState<_SecretHeader> {
  static const taps = 5;
  static const window = Duration(seconds: 3);
  final _times = <DateTime>[];

  Future<void> _tap() async {
    final t = DateTime.now();
    _times
      ..add(t)
      ..removeWhere((x) => t.difference(x) > window);
    if (_times.length < taps) return;
    _times.clear();
    if (ref.read(vitalsDevModeProvider)) return;
    await ref.read(vitalsDevModeProvider.notifier).set(true);
    if (!mounted) return;
    VitalsScreen._snack(
      context,
      context.tr(
        uz: '🧪 Dasturchi rejimi yoqildi',
        ru: '🧪 Режим разработчика включён',
        en: '🧪 Developer mode on',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.now;
    final from = DateTime(n.year, n.month, n.day - 6);
    String d(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}';
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      key: const Key('vitals-header'),
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.tr(
                  uz: 'Oxirgi 7 kun',
                  ru: 'Последние 7 дней',
                  en: 'Last 7 days',
                ),
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text('${d(from)} – ${d(n)}', style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.latest,
    required this.selected,
    required this.onTap,
  });

  final VitalKind kind;
  final Vital? latest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final v = latest;
    final status = v?.status;
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 32 - 10) / 2,
      child: AppCard(
        key: Key('vitals-tile-${kind.name}'),
        onTap: onTap,
        elevated: !selected,
        color: selected ? kind.color.withValues(alpha: 0.14) : null,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(kind.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    kind.label(context),
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (status != null && kind != VitalKind.weight)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor(status),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Shrinks instead of cutting the unit («121/80 mm sim. ust.» on
            // an iPhone SE).
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: v == null ? '—' : vitalValueText(v),
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (v != null)
                      TextSpan(
                        text: ' ${kind.unitText(context)}',
                        style: text.bodySmall,
                      ),
                  ],
                ),
                key: Key('vitals-tile-value-${kind.name}'),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
