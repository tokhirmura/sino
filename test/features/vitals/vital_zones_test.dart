import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/features/vitals/application/vital_zones.dart';
import 'package:sino/features/vitals/data/models.dart';
import 'package:sino/features/vitals/presentation/labels.dart';

const _low = VitalZone.low;
const _normal = VitalZone.normal;
const _elevated = VitalZone.elevated;
const _high = VitalZone.high;

Vital _vital(VitalKind kind, double value, [double? value2]) => Vital(
  id: 'x',
  kind: kind,
  value: value,
  value2: value2,
  measuredAt: DateTime(2026, 11, 21, 8),
);

/// Bands go from open to open without gaps or overlaps, in zone order.
void _expectContiguous(List<ZoneBand> bands) {
  expect([for (final b in bands) b.zone], [_low, _normal, _elevated, _high]);
  expect(bands.first.from, isNull);
  expect(bands.last.to, isNull);
  for (var i = 1; i < bands.length; i++) {
    expect(bands[i].from, bands[i - 1].to);
    expect(bands[i].from!, greaterThan(bands[i - 1].from ?? -1));
  }
}

void main() {
  group('pressure (ESH)', () {
    test('systolic boundaries, diastolic normal', () {
      expect(pressureZone(89, 70), _low);
      expect(pressureZone(90, 70), _normal);
      expect(pressureZone(129, 70), _normal);
      expect(pressureZone(130, 70), _elevated);
      expect(pressureZone(139, 70), _elevated);
      expect(pressureZone(140, 70), _high);
      expect(pressureZone(180, 70), _high);
    });

    test('diastolic boundaries, systolic normal', () {
      expect(pressureZone(115, 59), _low);
      expect(pressureZone(115, 60), _normal);
      expect(pressureZone(115, 84), _normal);
      expect(pressureZone(115, 85), _elevated);
      expect(pressureZone(115, 89), _elevated);
      expect(pressureZone(115, 90), _high);
    });

    test('the more worrying value decides', () {
      expect(pressureZone(118, 76), _normal);
      expect(pressureZone(135, 92), _high);
      expect(pressureZone(145, 80), _high);
      expect(pressureZone(135, 55), _elevated);
      expect(pressureZone(85, 92), _high);
      expect(pressureZone(85, 55), _low);
      expect(worse(_low, _normal), _low);
      expect(worse(_elevated, _low), _elevated);
      expect(worse(_high, _elevated), _high);
    });
  });

  test('fasting glucose boundaries', () {
    expect(glucoseZone(3.8), _low);
    expect(glucoseZone(3.9), _normal);
    expect(glucoseZone(5.5), _normal);
    expect(glucoseZone(5.6), _elevated);
    expect(glucoseZone(6.9), _elevated);
    expect(glucoseZone(7.0), _high);
    expect(glucoseZone(11.2), _high);
  });

  test('bands are contiguous and match the zone functions', () {
    _expectContiguous(systolicBands);
    _expectContiguous(diastolicBands);
    _expectContiguous(glucoseBands);
    expect(chartBands(VitalKind.pressure), systolicBands);
    expect(chartBands(VitalKind.glucose), glucoseBands);
    expect(chartBands(VitalKind.pulse), isEmpty);
    expect(chartBands(VitalKind.steps), isEmpty);
  });

  test('«me’yor» zone = «me’yorda» status of the tiles', () {
    for (var sys = 70.0; sys <= 200; sys++) {
      for (var dia = 40.0; dia <= 120; dia++) {
        final v = _vital(VitalKind.pressure, sys, dia);
        expect(
          zoneOf(v) == _normal,
          v.status == VitalStatus.normal,
          reason: '$sys/$dia',
        );
      }
    }
    for (var g = 20; g <= 200; g++) {
      final v = _vital(VitalKind.glucose, g / 10);
      expect(
        zoneOf(v) == _normal,
        v.status == VitalStatus.normal,
        reason: '${g / 10}',
      );
    }
  });

  test('zoneOf: only pressure (with both values) and glucose', () {
    expect(zoneOf(_vital(VitalKind.pressure, 142, 91)), _high);
    expect(zoneOf(_vital(VitalKind.pressure, 142)), isNull);
    expect(zoneOf(_vital(VitalKind.glucose, 6.1)), _elevated);
    expect(zoneOf(_vital(VitalKind.pulse, 140)), isNull);
  });

  testWidgets('zone names in Uzbek and the disclaimer', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLang.uz.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      [for (final z in VitalZone.values) zoneText(ctx, z)],
      ['Past', 'Me’yor', 'Yuqori me’yor', 'Baland'],
    );
    expect(
      zoneDisclaimer(ctx),
      contains('Shifokor maslahatini almashtirmaydi'),
    );
    expect(zoneDisclaimer(ctx), contains('tashxis emas'));
  });
}
