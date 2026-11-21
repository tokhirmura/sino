/// 30-day pressure / glucose report for a doctor (Sprint 2.0, S2-6),
/// without Flutter.
library;

import '../data/models.dart';
import 'vital_zones.dart';

/// Days in the report (today included).
const reportDays = 30;

/// Kinds that have a report (zones are defined for them).
bool hasReport(VitalKind k) =>
    k == VitalKind.pressure || k == VitalKind.glucose;

/// First day of the report window ending [now].
DateTime reportStart(DateTime now) =>
    DateTime(now.year, now.month, now.day - (reportDays - 1));

/// Position on the chart: days since [start], with the time of day as a
/// fraction (several measurements a day stand apart).
double reportX(DateTime t, DateTime start) =>
    t.difference(start).inMinutes / Duration.minutesPerDay;

/// Numbers for the summary line and the share text.
class ReportSummary {
  const ReportSummary({
    required this.count,
    required this.zones,
    this.avg,
    this.avg2,
    this.min,
    this.max,
  });

  final int count;

  /// Measurements per zone (every zone present, possibly 0).
  final Map<VitalZone, int> zones;

  /// Average value (systolic for pressure); `null` — no measurements.
  final double? avg;

  /// Average diastolic pressure.
  final double? avg2;
  final double? min;
  final double? max;

  /// Share of measurements in the «me’yor» zone, 0…1.
  double get normalShare => count == 0 ? 0 : zones[VitalZone.normal]! / count;
}

ReportSummary summarize(List<Vital> list) {
  final zones = {for (final z in VitalZone.values) z: 0};
  final values = <double>[];
  final values2 = <double>[];
  for (final v in list) {
    final z = zoneOf(v);
    if (z == null) continue;
    zones[z] = zones[z]! + 1;
    values.add(v.value);
    if (v.value2 != null) values2.add(v.value2!);
  }
  double? avg(List<double> xs) =>
      xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
  return ReportSummary(
    count: values.length,
    zones: zones,
    avg: avg(values),
    avg2: avg(values2),
    min: values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b),
    max: values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b),
  );
}

/// Only rows of [kind] inside the window, newest first.
List<Vital> reportRows(List<Vital> list, VitalKind kind, DateTime now) {
  final start = reportStart(now);
  return [
    for (final v in list)
      if (v.kind == kind &&
          !v.measuredAt.isBefore(start) &&
          !v.measuredAt.isAfter(now.add(const Duration(minutes: 5))))
        v,
  ]..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
}
