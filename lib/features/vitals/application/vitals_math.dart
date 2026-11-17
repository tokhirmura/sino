import 'dart:math' as math;

import '../data/models.dart';

/// One day of a 7-day chart; values are `null` on a day without data.
class DayPoint {
  const DayPoint(this.date, this.value, [this.value2]);

  final DateTime date;
  final double? value;
  final double? value2;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The last 7 days (oldest first, today last). Several measurements of a
/// day: steps — the largest (a daily total), weight and sleep — the
/// latest, the rest — the mean.
List<DayPoint> weekSeries(List<Vital> list, VitalKind kind, DateTime now) {
  final today = _day(now);
  return [
    for (var i = 6; i >= 0; i--)
      () {
        final day = DateTime(today.year, today.month, today.day - i);
        final of = [
          for (final v in list)
            if (v.kind == kind && _day(v.measuredAt) == day) v,
        ]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
        if (of.isEmpty) return DayPoint(day, null);
        double? mean(Iterable<double?> xs) {
          final vs = xs.whereType<double>().toList();
          return vs.isEmpty ? null : vs.reduce((a, b) => a + b) / vs.length;
        }

        return switch (kind) {
          VitalKind.steps => DayPoint(
            day,
            of.map((v) => v.value).reduce(math.max),
          ),
          VitalKind.weight || VitalKind.sleep => DayPoint(day, of.last.value),
          _ => DayPoint(
            day,
            mean(of.map((v) => v.value)),
            mean(of.map((v) => v.value2)),
          ),
        };
      }(),
  ];
}

/// Plausible input range of a value (rejects typos, not a norm).
({double min, double max}) inputRange(VitalKind k, {bool second = false}) =>
    switch (k) {
      VitalKind.pulse => (min: 30, max: 220),
      VitalKind.steps => (min: 0, max: 100000),
      VitalKind.sleep => (min: 0, max: 24),
      VitalKind.weight => (min: 20, max: 300),
      VitalKind.pressure => second ? (min: 30, max: 160) : (min: 60, max: 260),
      VitalKind.glucose => (min: 1, max: 35),
    };

/// Body mass index; `null` without both numbers.
double? bmi({double? weightKg, double? heightCm}) {
  if (weightKg == null || heightCm == null || heightCm <= 0) return null;
  final m = heightCm / 100;
  return weightKg / (m * m);
}

enum BmiLevel { under, normal, over, obese }

BmiLevel bmiLevel(double bmi) => bmi < 18.5
    ? BmiLevel.under
    : bmi < 25
    ? BmiLevel.normal
    : bmi < 30
    ? BmiLevel.over
    : BmiLevel.obese;

/// Test history for the demo (developer mode): one realistic value per
/// kind for each of the last 7 days that has none yet, so the charts are
/// never empty and nothing is duplicated. Deterministic for a given [now].
List<VitalInput> testHistory(List<Vital> existing, DateTime now) {
  final today = _day(now);
  final has = {for (final v in existing) (v.kind, _day(v.measuredAt))};
  final rnd = math.Random(today.millisecondsSinceEpoch ~/ 86400000);
  double around(double base, double spread, {int digits = 0}) {
    final v = base + (rnd.nextDouble() * 2 - 1) * spread;
    final p = math.pow(10, digits);
    return (v * p).round() / p;
  }

  final out = <VitalInput>[];
  for (var i = 6; i >= 0; i--) {
    final day = DateTime(today.year, today.month, today.day - i);
    // Morning measurement; today — not later than now.
    var at = DateTime(day.year, day.month, day.day, 8, 30);
    if (at.isAfter(now)) at = now;
    for (final k in VitalKind.values) {
      if (has.contains((k, day))) continue;
      final (value, value2) = switch (k) {
        VitalKind.pulse => (around(72, 6), null),
        VitalKind.steps => (around(7500, 2800), null),
        VitalKind.sleep => (around(7.2, 1.0, digits: 1), null),
        VitalKind.weight => (
          around(74.5 - (6 - i) * 0.1, 0.3, digits: 1),
          null,
        ),
        VitalKind.pressure => (around(119, 8), around(78, 5)),
        VitalKind.glucose => (around(5.0, 0.5, digits: 1), null),
      };
      out.add((kind: k, value: value, value2: value2, measuredAt: at));
    }
  }
  return out;
}
