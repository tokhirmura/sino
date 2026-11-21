import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/home/application/sino_index.dart';
import 'package:sino/features/home/application/weekly_report.dart';
import 'package:sino/features/home/data/sino_data.dart';
import 'package:sino/features/home/home_feature.dart';
import 'package:sino/features/home/presentation/report_screen.dart';

import '../../helpers/test_app.dart';

/// Saturday evening.
final _now = DateTime(2026, 11, 21, 20);

class _Repo implements SinoDataRepository {
  _Repo({this.empty = false});
  final bool empty;

  @override
  Future<SinoRaw> load({required DateTime from, required DateTime to}) => empty
      ? Future.value(const SinoRaw())
      : FakeSinoDataRepository(clock: () => _now).load(from: from, to: to);

  @override
  Future<bool> hasReservation() async => false;
}

/// 14 days, oldest first; [make] gets days-ago (13 … 0).
List<SinoDay> _history(SinoDayInput Function(DateTime d, int ago) make) {
  final today = DateTime(_now.year, _now.month, _now.day);
  return [
    for (var ago = 13; ago >= 0; ago--)
      () {
        final input = make(today.subtract(Duration(days: ago)), ago);
        return SinoDay(
          input: input,
          index: computeSinoIndex(input, kcalGoal: 2200, now: _now),
        );
      }(),
  ];
}

SinoDose _dose(DateTime d, int h, bool taken) => SinoDose(
  at: d.add(Duration(hours: h)),
  taken: taken,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildWeeklyReport', () {
    test('sums the last 7 days and compares with the week before', () {
      final r = buildWeeklyReport(
        _history(
          (d, ago) => SinoDayInput(
            date: d,
            // Last week: 4 glasses (index 50); this week: 8 (100), one day 6.
            glasses: ago >= 7 ? 4 : (ago == 3 ? 6 : 8),
            workouts: ago == 2 || ago == 5 ? 1 : 0,
            steps: ago < 7 ? 7000 : null,
            doses: ago < 7
                ? [_dose(d, 8, true), _dose(d, 21, ago != 1 && ago != 0)]
                : const [],
          ),
        ),
        now: _now,
      );
      expect(r.days, hasLength(7));
      expect(r.to, DateTime(2026, 11, 21));
      expect(r.from, DateTime(2026, 11, 15));
      expect(r.previousAverage, 50);
      expect(r.average, greaterThan(80));
      expect(r.delta, r.average! - 50);
      expect(r.glasses, 6 * 8 + 6);
      expect(r.waterGoalDays, 6);
      expect(r.glassesPerDay, closeTo(54 / 7, 1e-9));
      expect(r.workouts, 2);
      expect(r.stepsPerDay, 7000);
      // Today's 21:00 dose isn't due yet at 20:00; day 1 missed one.
      expect(r.dosesDue, 13);
      expect(r.dosesTaken, 12);
      // Best: the latest of the top-scoring days.
      expect(r.best!.date, isNot(DateTime(2026, 11, 18)));
      expect(
        r.best!.index!.score,
        r.days.map((d) => d.index!.score).reduce((a, b) => a > b ? a : b),
      );
    });

    test('empty week; no previous week → delta null', () {
      final empty = buildWeeklyReport(
        _history((d, _) => SinoDayInput(date: d)),
        now: _now,
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.best, isNull);
      expect(empty.dosesShare, isNull);
      expect(empty.glassesPerDay, isNull);

      final firstWeek = buildWeeklyReport(
        _history(
          (d, ago) => SinoDayInput(date: d, glasses: ago < 7 ? 8 : null),
        ),
        now: _now,
      );
      expect(firstWeek.average, 100);
      expect(firstWeek.previousAverage, isNull);
      expect(firstWeek.delta, isNull);
    });
  });

  test('home registers /report', () {
    expect(
      homeFullscreenRoutes.whereType<GoRoute>().map((r) => r.path),
      contains(AppRoutes.report),
    );
  });

  Future<List<(Uint8List, String)>> pumpReport(
    WidgetTester tester, {
    bool empty = false,
    AppLang lang = AppLang.uz,
  }) async {
    tester.view.physicalSize = const Size(412, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shared = <(Uint8List, String)>[];
    final prefs = await fakePrefs(signedIn: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appOverrides(prefs: prefs, useFake: true),
          sinoClockProvider.overrideWithValue(() => _now),
          sinoDataRepositoryProvider.overrideWithValue(_Repo(empty: empty)),
          reportSharerProvider.overrideWithValue(
            (png, text) async => shared.add((png, text)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: lang.locale,
          supportedLocales: AppLang.locales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const ReportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return shared;
  }

  testWidgets('report: card with average, chart, best day; share sends PNG', (
    tester,
  ) async {
    final shared = await pumpReport(tester);

    expect(find.text('Haftalik hisobot'), findsOneWidget);
    expect(find.text('15 – 21 noyabr'), findsWidgets);
    expect(find.byKey(const ValueKey('report-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-average')), findsOneWidget);
    // Fake history is one week long → no comparison yet.
    expect(find.text('Birinchi hafta 🌱'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-best')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-water')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-workouts')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-meds')), findsOneWidget);
    expect(find.text('Shifokor maslahatini almashtirmaydi'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('report-share')));
      for (var i = 0; i < 50 && shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(shared, hasLength(1));
    final (png, text) = shared.single;
    // PNG signature.
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(text, startsWith('Mening Sino haftam: o‘rtacha indeks '));
  });

  testWidgets('report in Russian', (tester) async {
    await pumpReport(tester, lang: AppLang.ru);
    expect(find.text('Отчёт за неделю'), findsOneWidget);
    expect(find.text('Лучший день'), findsOneWidget);
    expect(find.text('Поделиться'), findsOneWidget);
  });

  testWidgets('no data this week → empty state', (tester) async {
    await pumpReport(tester, empty: true);
    expect(find.text('Bu hafta hali ma’lumot yo‘q'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-share')), findsNothing);
  });

  testWidgets('week strip on home opens the report', (tester) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await fakePrefs(signedIn: true);
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: AppRoutes.home,
      routes: [...homeRoutes, ...homeFullscreenRoutes],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appOverrides(prefs: prefs, useFake: true),
          sinoClockProvider.overrideWithValue(() => _now),
          sinoDataRepositoryProvider.overrideWithValue(_Repo()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: AppLang.uz.locale,
          supportedLocales: AppLang.locales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-report')));
    await tester.pumpAndSettle();
    expect(find.byType(ReportScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('report-card')), findsOneWidget);
  });
}
