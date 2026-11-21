import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/vital_zones.dart';
import '../application/vitals_providers.dart';
import '../application/vitals_report.dart';
import '../data/models.dart';
import 'labels.dart';
import 'widgets/report_share.dart';
import 'widgets/zone_chart.dart';

/// Path of the 30-day report of [kind] (pressure or glucose).
String vitalsReportPath(VitalKind kind) =>
    '${AppRoutes.vitals}/report/${kind.name}';

/// Pressure / glucose for the last 30 days over colored zones, a summary,
/// the table — and «Shifokorga yuborish»: the same report as an image
/// with a text summary through the share sheet (S2-6).
class VitalsReportScreen extends ConsumerStatefulWidget {
  const VitalsReportScreen({super.key, required this.kind});

  final VitalKind kind;

  @override
  ConsumerState<VitalsReportScreen> createState() => _VitalsReportScreenState();
}

class _VitalsReportScreenState extends ConsumerState<VitalsReportScreen> {
  bool _sharing = false;
  final _buttonKey = GlobalKey();

  Future<void> _share(List<Vital> rows, DateTime now) async {
    setState(() => _sharing = true);
    try {
      final patient = ref.read(currentUserProvider).value?.fullName;
      final report = ReportBody(
        kind: widget.kind,
        rows: rows,
        now: now,
        forImage: true,
        patient: patient,
      );
      final png = await ref.read(reportCaptureProvider)(context, report);
      if (!mounted) return;
      final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
      await ref.read(reportShareProvider)(
        png,
        text: reportShareText(context, widget.kind, summarize(rows), now),
        fileName: 'sino_${widget.kind.name}_${_fileDate(now)}.png',
        origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final provider = vitalsReportProvider(kind);
    final now = DateTime.now();
    return AppScaffold(
      title: context.tr(
        uz: '${kind.label(context)} — 30 kun',
        ru: '${kind.label(context)} — 30 дней',
        en: '${kind.label(context)} — 30 days',
      ),
      subtitle: periodText(now),
      body: AsyncValueView(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        loading: () => const SkeletonLoader(count: 3, kind: SkeletonKind.card),
        data: (rows) => rows.isEmpty
            ? EmptyState(
                key: const Key('vitals-report-empty'),
                emoji: kind.emoji,
                color: kind.color,
                title: context.tr(
                  uz: '30 kunda o‘lchov yo‘q',
                  ru: 'За 30 дней измерений нет',
                  en: 'No measurements in 30 days',
                ),
                message: context.tr(
                  uz: 'O‘lchovlarni kiriting — hisobot shu yerda paydo bo‘ladi.',
                  ru: 'Вносите измерения — отчёт появится здесь.',
                  en: 'Log measurements — the report shows up here.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: [
                  ReportBody(kind: kind, rows: rows, now: now),
                  const SizedBox(height: AppSpacing.md),
                  // Its rect anchors the share sheet on iPad.
                  KeyedSubtree(
                    key: _buttonKey,
                    child: PrimaryButton(
                      key: const Key('vitals-report-share'),
                      label: context.tr(
                        uz: 'Shifokorga yuborish',
                        ru: 'Отправить врачу',
                        en: 'Send to a doctor',
                      ),
                      icon: Icons.ios_share_rounded,
                      loading: _sharing,
                      onPressed: _sharing ? null : () => _share(rows, now),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');

String _date(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

String _fileDate(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';

/// «22.10.2026 – 21.11.2026».
String periodText(DateTime now) => '${_date(reportStart(now))} – ${_date(now)}';

/// «128/82» or «5.9».
String _avgText(VitalKind kind, ReportSummary s) => s.avg == null
    ? '—'
    : kind.hasSecondValue && s.avg2 != null
    ? '${s.avg!.round()}/${s.avg2!.round()}'
    : formatNumber(kind, s.avg!);

/// The text that goes with the image.
String reportShareText(
  BuildContext context,
  VitalKind kind,
  ReportSummary s,
  DateTime now,
) {
  final unit = kind.unitText(context);
  final avg = _avgText(kind, s);
  final z = s.zones;
  final zones = [
    for (final zone in VitalZone.values)
      if (z[zone]! > 0) '${zoneText(context, zone).toLowerCase()} ${z[zone]}',
  ].join(', ');
  return context.tr(
    uz:
        'Sino — ${kind.label(context)}, ${periodText(now)}: ${s.count} ta '
        'o‘lchov, o‘rtacha $avg $unit; $zones. ${zoneDisclaimer(context)}',
    ru:
        'Sino — ${kind.label(context)}, ${periodText(now)}: измерений '
        '${s.count}, в среднем $avg $unit; $zones. ${zoneDisclaimer(context)}',
    en:
        'Sino — ${kind.label(context)}, ${periodText(now)}: ${s.count} '
        'measurements, average $avg $unit; $zones. ${zoneDisclaimer(context)}',
  );
}

/// The report itself: on the screen and, with [forImage], as the image
/// for the doctor (title with the period and the patient, no animations).
class ReportBody extends StatelessWidget {
  const ReportBody({
    super.key,
    required this.kind,
    required this.rows,
    required this.now,
    this.forImage = false,
    this.patient,
  });

  final VitalKind kind;

  /// Newest first.
  final List<Vital> rows;
  final DateTime now;
  final bool forImage;
  final String? patient;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = summarize(rows);
    final unit = kind.unitText(context);
    final animate = !forImage;
    const gap = SizedBox(height: AppSpacing.cardGap);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (forImage) ...[
          Text(
            'Sino · ${kind.label(context)}',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            [
              ?patient,
              periodText(now),
            ].where((x) => x.trim().isNotEmpty).join(' · '),
            style: text.bodyMedium,
          ),
          gap,
        ] else
          const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: StatTile(
                key: const Key('vitals-report-avg'),
                value: _avgText(kind, s),
                unit: unit,
                label: context.tr(uz: 'O‘rtacha', ru: 'Среднее', en: 'Average'),
                emoji: kind.emoji,
                color: kind.color,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: StatTile(
                key: const Key('vitals-report-normal'),
                value: '${(s.normalShare * 100).round()}%',
                label: context.tr(uz: 'Me’yorda', ru: 'В норме', en: 'Normal'),
                emoji: '✅',
                color: AppColors.good,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: StatTile(
                key: const Key('vitals-report-high'),
                value: '${s.zones[VitalZone.high]}',
                label: context.tr(uz: 'Baland', ru: 'Высокое', en: 'High'),
                emoji: '⚠️',
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        gap,
        for (final lower in kind.hasSecondValue ? [false, true] : [false]) ...[
          AppCard(
            animate: animate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (kind.hasSecondValue)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      lower
                          ? context.tr(
                              uz: 'Pastki (diastolik) bosim',
                              ru: 'Нижнее (диастолическое) давление',
                              en: 'Lower (diastolic) pressure',
                            )
                          : context.tr(
                              uz: 'Yuqori (sistolik) bosim',
                              ru: 'Верхнее (систолическое) давление',
                              en: 'Upper (systolic) pressure',
                            ),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ZoneChart(
                  key: Key('vitals-report-chart${lower ? '-lower' : ''}'),
                  kind: kind,
                  rows: rows,
                  now: now,
                  diastolic: lower,
                  height: kind.hasSecondValue ? 170 : 210,
                  animate: animate,
                ),
                const SizedBox(height: AppSpacing.xs),
                ZoneLegend(kind: kind, diastolic: lower),
              ],
            ),
          ),
          gap,
        ],
        AppCard(
          key: const Key('vitals-report-table'),
          animate: animate,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            children: [
              _Row(
                date: context.tr(uz: 'Sana', ru: 'Дата', en: 'Date'),
                value: unit,
                zone: context.tr(uz: 'Zona', ru: 'Зона', en: 'Zone'),
                header: true,
              ),
              for (final v in rows)
                _Row(
                  date:
                      '${_two(v.measuredAt.day)}.${_two(v.measuredAt.month)} '
                      '${_two(v.measuredAt.hour)}:${_two(v.measuredAt.minute)}',
                  value: vitalValueText(v),
                  zone: zoneOf(v),
                ),
            ],
          ),
        ),
        gap,
        Text(
          zoneDisclaimer(context),
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
    return forImage
        ? Padding(padding: const EdgeInsets.all(AppSpacing.md), child: content)
        : content;
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.date,
    required this.value,
    required this.zone,
    this.header = false,
  });

  final String date;
  final String value;

  /// [VitalZone] or a header label.
  final Object? zone;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = header
        ? text.labelMedium?.copyWith(fontWeight: FontWeight.w700)
        : text.bodyMedium;
    final z = zone;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs + 2),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(date, style: style)),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: header
                  ? style
                  : style?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 4,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: z is VitalZone
                  // «Yuqori me’yor» shrinks in a narrow column, never cut.
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Pill(zoneText(context, z), color: zoneColor(z)),
                    )
                  : Text(z?.toString() ?? '', style: style),
            ),
          ),
        ],
      ),
    );
  }
}
