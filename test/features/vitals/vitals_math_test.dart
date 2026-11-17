import 'package:flutter_test/flutter_test.dart';
import 'package:sino/features/vitals/application/vitals_math.dart';
import 'package:sino/features/vitals/data/models.dart';

final _now = DateTime(2026, 11, 18, 14);
var _id = 0;

Vital _v(
  VitalKind k,
  double value,
  int daysAgo, {
  int hour = 8,
  double? value2,
}) => Vital(
  id: '${_id++}',
  kind: k,
  value: value,
  value2: value2,
  measuredAt: DateTime(2026, 11, 18 - daysAgo, hour),
);

void main() {
  test('week series: 7 days oldest first, empty days null', () {
    final s = weekSeries(
      [_v(VitalKind.pulse, 70, 0), _v(VitalKind.pulse, 80, 6)],
      VitalKind.pulse,
      _now,
    );
    expect(s, hasLength(7));
    expect(s.first.date, DateTime(2026, 11, 12));
    expect(s.last.date, DateTime(2026, 11, 18));
    expect(s.first.value, 80);
    expect(s.last.value, 70);
    expect(s[3].value, isNull);
  });

  test('aggregation of a day: mean / max steps / latest weight', () {
    final list = [
      _v(VitalKind.pulse, 60, 0, hour: 8),
      _v(VitalKind.pulse, 80, 0, hour: 20),
      _v(VitalKind.steps, 3000, 0, hour: 12),
      _v(VitalKind.steps, 9000, 0, hour: 21),
      _v(VitalKind.weight, 75, 0, hour: 7),
      _v(VitalKind.weight, 74.2, 0, hour: 21),
      _v(VitalKind.pressure, 120, 0, value2: 80),
      _v(VitalKind.pressure, 130, 0, hour: 20, value2: 90),
      _v(VitalKind.pulse, 99, 7), // 8 days ago — outside the week
    ];
    expect(weekSeries(list, VitalKind.pulse, _now).last.value, 70);
    expect(weekSeries(list, VitalKind.steps, _now).last.value, 9000);
    expect(weekSeries(list, VitalKind.weight, _now).last.value, 74.2);
    final p = weekSeries(list, VitalKind.pressure, _now).last;
    expect(p.value, 125);
    expect(p.value2, 85);
    expect(
      weekSeries(list, VitalKind.pulse, _now).where((d) => d.value != null),
      hasLength(1),
    );
  });

  test('BMI and its levels', () {
    expect(bmi(weightKg: 74, heightCm: 178), closeTo(23.36, 0.01));
    expect(bmi(weightKg: 74), isNull);
    expect(bmiLevel(18.4), BmiLevel.under);
    expect(bmiLevel(18.5), BmiLevel.normal);
    expect(bmiLevel(24.9), BmiLevel.normal);
    expect(bmiLevel(25), BmiLevel.over);
    expect(bmiLevel(30), BmiLevel.obese);
  });

  test('input ranges reject typos', () {
    expect(inputRange(VitalKind.pulse).max, 220);
    expect(inputRange(VitalKind.pressure).min, 60);
    expect(inputRange(VitalKind.pressure, second: true).max, 160);
  });

  group('test history', () {
    test('empty week → 7 days × 6 kinds, not in the future', () {
      final h = testHistory(const [], _now);
      expect(h, hasLength(42));
      for (final i in h) {
        expect(i.measuredAt.isAfter(_now), isFalse);
        final r = inputRange(i.kind);
        expect(i.value, inInclusiveRange(r.min, r.max));
        if (i.kind == VitalKind.pressure) {
          expect(i.value2, lessThan(i.value));
        } else {
          expect(i.value2, isNull);
        }
      }
      // Every kind has every day → no empty chart.
      final vitals = [
        for (final i in h)
          Vital(
            id: '${_id++}',
            kind: i.kind,
            value: i.value,
            value2: i.value2,
            measuredAt: i.measuredAt,
          ),
      ];
      for (final k in VitalKind.values) {
        expect(
          weekSeries(vitals, k, _now).every((d) => d.value != null),
          isTrue,
          reason: k.name,
        );
      }
    });

    test('fills only empty day × kind; deterministic', () {
      final existing = [
        for (var d = 0; d < 7; d++) _v(VitalKind.pulse, 70, d),
        _v(VitalKind.glucose, 5, 2),
      ];
      final h = testHistory(existing, _now);
      expect(h, hasLength(42 - 7 - 1));
      expect(h.where((i) => i.kind == VitalKind.pulse), isEmpty);
      expect(
        h.where(
          (i) =>
              i.kind == VitalKind.glucose && i.measuredAt.day == _now.day - 2,
        ),
        isEmpty,
      );
      expect(
        testHistory(existing, _now).map((i) => i.value).toList(),
        h.map((i) => i.value).toList(),
      );
    });

    test('today early in the morning: today’s value is «now»', () {
      final early = DateTime(2026, 11, 18, 6, 15);
      final today = testHistory(
        const [],
        early,
      ).where((i) => i.measuredAt.day == 18);
      expect(today.every((i) => i.measuredAt == early), isTrue);
    });
  });
}
