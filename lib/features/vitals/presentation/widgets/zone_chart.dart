import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/vital_zones.dart';
import '../../application/vitals_report.dart';
import '../../data/models.dart';
import '../labels.dart';

/// 30-day chart of pressure / glucose over colored zones (S2-6): every
/// measurement is a dot at its day and time. Pressure is drawn as two
/// charts — systolic and ([diastolic]) diastolic — each over its own zones:
/// on one chart a normal diastolic 76 would sit in the systolic «low» zone.
class ZoneChart extends StatelessWidget {
  const ZoneChart({
    super.key,
    required this.kind,
    required this.rows,
    required this.now,
    this.diastolic = false,
    this.height = 200,
    this.animate = true,
  });

  final VitalKind kind;

  /// Pressure: the lower value (`value2`) over the diastolic zones.
  final bool diastolic;

  /// Newest first (as [vitalsReportProvider] gives them).
  final List<Vital> rows;
  final DateTime now;
  final double height;

  /// `false` for the image sent to the doctor (no implicit animation).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final start = reportStart(now);
    final ordered = rows.reversed.toList();
    final bands = zoneBandsOf(kind, diastolic: diastolic);
    double? pick(Vital v) => diastolic ? v.value2 : v.value;

    final values = [for (final v in rows) ?pick(v)];
    // Keep the «me’yor» band in view even for a few measurements.
    final normal = bands.firstWhere((b) => b.zone == VitalZone.normal);
    final lo = math.min(
      values.fold<double>(normal.from!, math.min),
      normal.from!,
    );
    final hi = math.max(values.fold<double>(normal.to!, math.max), normal.to!);
    final pad = kind.decimal ? 0.8 : 10.0;
    final minY = (lo - pad)
        .floorToDouble()
        .clamp(0, double.infinity)
        .toDouble();
    final maxY = (hi + pad).ceilToDouble();

    LineChartBarData line(double? Function(Vital) pick, Color color) =>
        LineChartBarData(
          spots: [
            for (final v in ordered)
              if (pick(v) != null)
                FlSpot(reportX(v.measuredAt, start), pick(v)!),
          ],
          color: color,
          barWidth: 2.5,
          isCurved: false,
          dotData: FlDotData(
            getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
              radius: 3.5,
              color: color,
              strokeWidth: 1.5,
              strokeColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        );

    String date(double x) {
      final d = start.add(Duration(days: x.round()));
      return '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}';
    }

    return SizedBox(
      height: height,
      child: LineChart(
        duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
        LineChartData(
          minX: 0,
          maxX: reportDays.toDouble(),
          minY: minY,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              for (final b in bands)
                if ((b.to ?? maxY) > minY && (b.from ?? minY) < maxY)
                  HorizontalRangeAnnotation(
                    y1: math.max(b.from ?? minY, minY),
                    y2: math.min(b.to ?? maxY, maxY),
                    color: zoneColor(b.zone).withValues(alpha: 0.16),
                  ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, meta) => v == meta.max || v == meta.min
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(
                          formatNumber(kind, v),
                          style: text.labelSmall,
                        ),
                      ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 7,
                getTitlesWidget: (v, meta) => v > reportDays - 3
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(date(v), style: text.labelSmall),
                      ),
              ),
            ),
          ),
          lineBarsData: [line(pick, diastolic ? AppColors.violet : kind.color)],
        ),
      ),
    );
  }
}

/// Colored squares with zone names under the chart.
class ZoneLegend extends StatelessWidget {
  const ZoneLegend({super.key, required this.kind, this.diastolic = false});

  final VitalKind kind;
  final bool diastolic;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final b in zoneBandsOf(kind, diastolic: diastolic))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: zoneColor(b.zone),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 10),
              ),
              const SizedBox(width: 4),
              Text(
                '${zoneText(context, b.zone)} ${bandText(kind, b)}',
                style: text.labelSmall,
              ),
            ],
          ),
      ],
    );
  }
}

/// Zones of the chart: diastolic ones for the lower pressure value.
List<ZoneBand> zoneBandsOf(VitalKind kind, {bool diastolic = false}) =>
    diastolic && kind == VitalKind.pressure ? diastolicBands : chartBands(kind);

/// «< 90», «90–129», «≥ 140».
String bandText(VitalKind kind, ZoneBand b) {
  String n(double v) => formatNumber(kind, v);
  final step = kind.decimal ? 0.1 : 1;
  if (b.from == null) return '< ${n(b.to!)}';
  if (b.to == null) return '≥ ${n(b.from!)}';
  return '${n(b.from!)}–${n(b.to! - step)}';
}
