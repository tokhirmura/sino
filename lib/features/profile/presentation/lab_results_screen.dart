import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/pill.dart';
import '../data/medical_repository.dart';
import 'labels.dart';

/// `lab_results`, newest first; each with a reference-range scale.
class LabResultsScreen extends ConsumerWidget {
  const LabResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labs = ref.watch(labResultsProvider);
    return AppScaffold(
      title: context.tr(uz: 'Tahlillar', ru: 'Анализы', en: 'Lab results'),
      body: labs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(labResultsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              emoji: '🧪',
              title: context.tr(
                uz: 'Hozircha tahlillar yo‘q',
                ru: 'Пока нет анализов',
                en: 'No lab results yet',
              ),
            );
          }
          final outside = list.where((l) => l.status != LabStatus.normal);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(labResultsProvider.future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _Summary(total: list.length, outside: outside.length),
                const SizedBox(height: 12),
                for (final l in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LabCard(lab: l),
                  ),
                Text(
                  context.tr(
                    uz:
                        'Shifokor maslahatini almashtirmaydi. Natijalarni '
                        'shifokoringiz bilan muhokama qiling.',
                    ru:
                        'Не заменяет консультацию врача. Обсудите результаты '
                        'с вашим врачом.',
                    en:
                        'Does not replace a doctor’s advice. Discuss the '
                        'results with your doctor.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.total, required this.outside});

  final int total;
  final int outside;

  @override
  Widget build(BuildContext context) {
    final ok = outside == 0;
    return AppCard(
      color: (ok ? AppColors.good : AppColors.amber).withValues(alpha: 0.12),
      child: Row(
        children: [
          Text(ok ? '✅' : '⚠️', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ok
                  ? context.tr(
                      uz: 'Barcha $total ko‘rsatkich me’yorda',
                      ru: 'Все $total показателей в норме',
                      en: 'All $total results are normal',
                    )
                  : context.tr(
                      uz: '$total tadan $outside tasi me’yordan tashqarida',
                      ru: '$outside из $total вне нормы',
                      en: '$outside of $total outside the normal range',
                    ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabCard extends StatelessWidget {
  const _LabCard({required this.lab});

  final LabResult lab;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = labColor(lab.status);
    final unit = lab.unit == null ? '' : ' ${lab.unit}';
    final range = switch ((lab.refLow, lab.refHigh)) {
      (final lo?, final hi?) when lo > 0 => '${formatNum(lo)}–${formatNum(hi)}',
      (_, final hi?) => '< ${formatNum(hi)}',
      (final lo?, null) => '> ${formatNum(lo)}',
      _ => null,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(lab.name, style: text.titleSmall)),
              Text(
                '${formatNum(lab.value)}$unit',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: lab.status == LabStatus.normal ? null : color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LabScale(lab: lab),
          const SizedBox(height: 8),
          Row(
            children: [
              Pill(labStatusLabel(context, lab.status), color: color),
              const SizedBox(width: 8),
              if (range != null)
                Expanded(
                  child: Text(
                    '${context.tr(uz: 'Me’yor', ru: 'Норма', en: 'Normal')}: '
                    '$range$unit',
                    style: text.bodySmall,
                  ),
                )
              else
                const Spacer(),
              Text(shortDate(context, lab.takenAt), style: text.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal bar: grey track, green normal zone, dot at the value.
class LabScale extends StatelessWidget {
  const LabScale({super.key, required this.lab});

  final LabResult lab;

  /// Visible range of the bar: the normal zone plus margins, always
  /// including the value.
  static (double, double) bounds(LabResult l) {
    final lo = l.refLow ?? l.value;
    final hi = l.refHigh ?? l.value;
    final span = math.max(hi - lo, l.value.abs() * 0.2);
    final pad = span <= 0 ? 1.0 : span * 0.35;
    var min = math.min(lo, l.value) - pad;
    if (min < 0 && lo >= 0 && l.value >= 0) min = 0;
    final max = math.max(hi, l.value) + pad;
    return (min, max);
  }

  @override
  Widget build(BuildContext context) {
    final (min, max) = bounds(lab);
    double pos(double v) => ((v - min) / (max - min)).clamp(0.0, 1.0);
    final zoneStart = pos(lab.refLow ?? min);
    final zoneEnd = pos(lab.refHigh ?? max);
    final color = labColor(lab.status);
    final track = Theme.of(context).colorScheme.outlineVariant;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 16,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: track.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Positioned(
                left: w * zoneStart,
                width: math.max(2, w * (zoneEnd - zoneStart)),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.good.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                left: (w * pos(lab.value) - 8).clamp(0.0, w - 16),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
