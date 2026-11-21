import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/vitals/application/vital_zones.dart';
import 'package:sino/features/vitals/application/vitals_report.dart';
import 'package:sino/features/vitals/data/models.dart';
import 'package:sino/features/vitals/data/vitals_repository.dart';
import 'package:sino/features/vitals/presentation/vitals_report_screen.dart';
import 'package:sino/features/vitals/presentation/widgets/report_share.dart';
import 'package:sino/features/vitals/presentation/widgets/zone_chart.dart';

final _now = DateTime(2026, 11, 21, 12);

Vital _p(int daysAgo, double sys, double dia, {int hour = 8}) => Vital(
  id: 'p$daysAgo-$hour',
  kind: VitalKind.pressure,
  value: sys,
  value2: dia,
  measuredAt: DateTime(_now.year, _now.month, _now.day - daysAgo, hour),
);

/// Pressure rows relative to the real today (for the screen).
List<Map<String, dynamic>> _pressureRows() {
  final n = DateTime.now();
  Map<String, dynamic> row(int daysAgo, double sys, double dia) => {
    'id': 'r$daysAgo',
    'kind': 'pressure',
    'value': sys,
    'value2': dia,
    'measured_at': DateTime(
      n.year,
      n.month,
      n.day - daysAgo,
      0,
      5,
    ).toUtc().toIso8601String(),
  };
  return [
    row(0, 118, 76), // normal
    row(3, 134, 80), // elevated
    row(10, 146, 92), // high
    row(20, 122, 78), // normal
    row(40, 180, 110), // outside the 30 days
  ];
}

void main() {
  group('pure', () {
    test(
      'window: 30 days with today; outside rows and other kinds dropped',
      () {
        expect(reportStart(_now), DateTime(2026, 10, 23));
        final rows = reportRows(
          [
            _p(0, 120, 80),
            _p(29, 120, 80),
            _p(30, 120, 80),
            Vital(id: 'g', kind: VitalKind.glucose, value: 5, measuredAt: _now),
          ],
          VitalKind.pressure,
          _now,
        );
        expect([for (final r in rows) r.id], ['p0-8', 'p29-8']);
      },
    );

    test('x on the chart: day + time of day', () {
      final start = reportStart(_now);
      expect(reportX(start, start), 0);
      expect(reportX(DateTime(2026, 10, 24, 12), start), 1.5);
    });

    test('summary: averages and zones', () {
      final s = summarize([
        _p(0, 118, 76),
        _p(1, 134, 80),
        _p(2, 146, 92),
        _p(3, 122, 78),
      ]);
      expect(s.count, 4);
      expect(s.avg, 130);
      expect(s.avg2, 81.5);
      expect(s.min, 118);
      expect(s.max, 146);
      expect(s.zones[VitalZone.normal], 2);
      expect(s.zones[VitalZone.elevated], 1);
      expect(s.zones[VitalZone.high], 1);
      expect(s.zones[VitalZone.low], 0);
      expect(s.normalShare, 0.5);
      expect(summarize(const []).avg, isNull);
      expect(summarize(const []).normalShare, 0);
    });

    test('band labels', () {
      expect(bandText(VitalKind.pressure, systolicBands[0]), '< 90');
      expect(bandText(VitalKind.pressure, systolicBands[1]), '90–129');
      expect(bandText(VitalKind.pressure, systolicBands[3]), '≥ 140');
      expect(bandText(VitalKind.glucose, glucoseBands[2]), '5.6–6.9');
    });
  });

  group('screen', () {
    late List<(Uint8List, String, String)> shared;
    late List<Widget> captured;

    Future<void> pump(WidgetTester tester, {bool empty = false}) async {
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'core.fake_signed_in': true,
        FakeVitalsRepository.listKey: jsonEncode(empty ? [] : _pressureRows()),
      });
      final prefs = await SharedPreferences.getInstance();
      shared = [];
      captured = [];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...appOverrides(prefs: prefs, useFake: true),
            reportCaptureProvider.overrideWithValue((context, report) async {
              captured.add(report);
              return Uint8List.fromList([1, 2, 3]);
            }),
            reportShareProvider.overrideWithValue((
              png, {
              required text,
              required fileName,
              origin,
            }) async {
              shared.add((png, text, fileName));
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: AppLang.uz.locale,
            supportedLocales: AppLang.locales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const VitalsReportScreen(kind: VitalKind.pressure),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('chart over zones, summary, table with zone pills', (
      tester,
    ) async {
      await pump(tester);
      // Pressure: one chart per value, each over its own zones.
      expect(find.byType(ZoneChart), findsNWidgets(2));
      expect(find.text('Yuqori me’yor 130–139'), findsOneWidget); // systolic
      expect(find.text('Yuqori me’yor 85–89'), findsOneWidget); // diastolic
      // 4 rows in 30 days (the 40-day-old one is out).
      final table = find.byKey(const Key('vitals-report-table'));
      expect(
        find.descendant(of: table, matching: find.text('118/76')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: table, matching: find.text('180/110')),
        findsNothing,
      );
      expect(
        find.descendant(of: table, matching: find.text('Baland')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: table, matching: find.text('Me’yor')),
        findsNWidgets(2),
      );
      expect(find.text('130/82'), findsOneWidget); // average
      expect(find.text('50%'), findsOneWidget); // normal share
      expect(find.textContaining('Shifokor maslahatini'), findsOneWidget);
    });

    testWidgets('«Shifokorga yuborish»: image of the report + summary text', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('vitals-report-share')));
      await tester.pumpAndSettle();

      expect(captured, hasLength(1));
      final body = captured.single as ReportBody;
      expect(body.forImage, isTrue);
      expect(body.rows, hasLength(4));

      expect(shared, hasLength(1));
      final (png, text, fileName) = shared.single;
      expect(png, [1, 2, 3]);
      expect(fileName, startsWith('sino_pressure_'));
      expect(text, contains('4 ta o‘lchov'));
      expect(text, contains('o‘rtacha 130/82'));
      expect(text, contains('me’yor 2'));
      expect(text, contains('baland 1'));
      expect(text, contains('Shifokor maslahatini almashtirmaydi'));
    });

    testWidgets('no measurements in 30 days → empty state', (tester) async {
      await pump(tester, empty: true);
      expect(find.byKey(const Key('vitals-report-empty')), findsOneWidget);
      expect(find.byKey(const Key('vitals-report-share')), findsNothing);
    });
  });

  testWidgets('the real capture renders the whole report into a PNG', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
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
    final rows = [_p(0, 118, 76), _p(3, 134, 80), _p(10, 146, 92)];
    final png = await tester.runAsync(
      () => captureReport(
        ctx,
        ReportBody(
          kind: VitalKind.pressure,
          rows: rows,
          now: _now,
          forImage: true,
          patient: 'Aziz',
        ),
      ),
    );
    // PNG signature.
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(png.length, greaterThan(1000));
  });
}
