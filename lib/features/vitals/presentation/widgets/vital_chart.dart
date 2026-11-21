import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/vital_zones.dart';
import '../../application/vitals_math.dart';
import '../../data/models.dart';
import '../labels.dart';

/// 7-day chart of a kind: bars for steps, lines for the rest (two for
/// pressure); the general reference range is a light band.
class VitalChart extends StatelessWidget {
  const VitalChart({super.key, required this.kind, required this.points});

  final VitalKind kind;
  final List<DayPoint> points;

  @override
  Widget build(BuildContext context) {
    final has = points.any((p) => p.value != null);
    final text = Theme.of(context).textTheme;
    if (!has) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            context.tr(
              uz: 'Bu hafta o‘lchov yo‘q — «Qo‘shish» bosing',
              ru: 'За неделю нет измерений — нажмите «Добавить»',
              en: 'No measurements this week — tap “Add”',
            ),
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final values = [
      for (final p in points) ...[?p.value, ?p.value2],
      if (kind.low != null && kind != VitalKind.steps) kind.low!,
      if (kind.high != null) kind.high!,
      if (kind.low2 != null) kind.low2!,
    ];
    var minY = values.reduce(math.min);
    var maxY = values.reduce(math.max);
    final pad = math.max((maxY - minY) * 0.15, kind.decimal ? 0.5 : 5);
    minY = kind == VitalKind.steps ? 0 : (minY - pad).floorToDouble();
    maxY = (maxY + pad).ceilToDouble();
    if (minY < 0) minY = 0;

    final grid = Theme.of(context).dividerColor.withValues(alpha: 0.4);
    final titles = FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: kind == VitalKind.steps ? 44 : 36,
          getTitlesWidget: (v, meta) => v == meta.max || v == meta.min
              ? const SizedBox.shrink()
              : SideTitleWidget(
                  meta: meta,
                  child: Text(
                    kind == VitalKind.steps && v >= 1000
                        ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k'
                        : formatNumber(kind, v),
                    style: text.labelSmall,
                  ),
                ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: 1,
          getTitlesWidget: (v, meta) {
            final i = v.round();
            if (i < 0 || i >= points.length || v != i) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              meta: meta,
              child: Text(
                i == points.length - 1
                    ? context.tr(uz: 'Bugun', ru: 'Сег.', en: 'Today')
                    : weekdayShort(context, points[i].date.weekday),
                style: text.labelSmall,
              ),
            );
          },
        ),
      ),
    );
    final band = kind.low != null && kind.high != null
        ? [
            HorizontalRangeAnnotation(
              y1: kind.low!,
              y2: kind.high!,
              color: AppColors.good.withValues(alpha: 0.10),
            ),
          ]
        : <HorizontalRangeAnnotation>[];

    final Widget chart;
    if (kind == VitalKind.steps) {
      chart = BarChart(
        BarChartData(
          minY: minY,
          maxY: maxY,
          titlesData: titles,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: grid, strokeWidth: 1),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: kind.low!,
                color: AppColors.good,
                strokeWidth: 1.5,
                dashArray: [6, 4],
              ),
            ],
          ),
          barTouchData: BarTouchData(enabled: false),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: points[i].value ?? 0,
                    width: 16,
                    color: (points[i].value ?? 0) >= kind.low!
                        ? kind.color
                        : kind.color.withValues(alpha: 0.45),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    } else {
      LineChartBarData line(
        double? Function(DayPoint) pick,
        Color color, {
        bool area = true,
      }) => LineChartBarData(
        spots: [
          for (var i = 0; i < points.length; i++)
            if (pick(points[i]) != null) FlSpot(i.toDouble(), pick(points[i])!),
        ],
        color: color,
        barWidth: 3,
        isCurved: true,
        preventCurveOverShooting: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: area,
          color: color.withValues(alpha: 0.12),
        ),
      );
      chart = LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          titlesData: titles,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: grid, strokeWidth: 1),
          ),
          rangeAnnotations: RangeAnnotations(
            // Glucose: colored zones (S2-6). Pressure keeps the two
            // neutral ranges — one set of zones can't fit both lines; its
            // zones are on the 30-day report, one chart per value.
            horizontalRangeAnnotations: kind == VitalKind.glucose
                ? [
                    for (final b in chartBands(kind))
                      if ((b.to ?? maxY) > minY && (b.from ?? minY) < maxY)
                        HorizontalRangeAnnotation(
                          y1: math.max(b.from ?? minY, minY),
                          y2: math.min(b.to ?? maxY, maxY),
                          color: zoneColor(b.zone).withValues(alpha: 0.14),
                        ),
                  ]
                : [
                    ...band,
                    if (kind.low2 != null && kind.high2 != null)
                      HorizontalRangeAnnotation(
                        y1: kind.low2!,
                        y2: kind.high2!,
                        color: AppColors.sky.withValues(alpha: 0.08),
                      ),
                  ],
          ),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            // Pressure: two lines without fill — the systolic fill would
            // cover the diastolic line.
            line((p) => p.value, kind.color, area: kind != VitalKind.pressure),
            if (kind == VitalKind.pressure)
              line((p) => p.value2, AppColors.violet, area: false),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: Key('vitals-chart-${kind.name}'),
          height: 200,
          child: Padding(
            padding: const EdgeInsets.only(right: 8, top: 8),
            child: chart,
          ),
        ),
        if (kind == VitalKind.pressure)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 16,
              children: [
                _Legend(
                  color: kind.color,
                  text: context.tr(
                    uz: 'Sistolik (yuqori)',
                    ru: 'Систолическое',
                    en: 'Systolic',
                  ),
                ),
                _Legend(
                  color: AppColors.violet,
                  text: context.tr(
                    uz: 'Diastolik (pastki)',
                    ru: 'Диастолическое',
                    en: 'Diastolic',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(text, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}
