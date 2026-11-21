import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/workouts/application/air_quality.dart';
import 'package:sino/features/workouts/application/plan_generator.dart';
import 'package:sino/features/workouts/data/models.dart';
import 'package:sino/features/workouts/data/workouts_repository.dart';
import 'package:sino/features/workouts/presentation/workouts_screen.dart';

String _aqi(int aqi, {Duration age = const Duration(minutes: 10)}) =>
    jsonEncode({
      'aqi': aqi,
      'at': DateTime.now().subtract(age).toUtc().toIso8601String(),
      'place': {'uz': 'Toshkent', 'ru': 'Ташкент', 'en': 'Tashkent'},
    });

Future<void> _pump(WidgetTester tester, Map<String, Object> prefs) async {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'core.fake_signed_in': true,
    ...prefs,
  });
  final p = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(prefs: p, useFake: true),
      child: MaterialApp(
        theme: AppTheme.light,
        locale: AppLang.uz.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const WorkoutsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _selected(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(find.byKey(Key(key))).selected;

void main() {
  test('today’s AQI: fresh only', () async {
    SharedPreferences.setMockInitialValues({todayAqiKey: _aqi(135)});
    final prefs = await SharedPreferences.getInstance();
    final a = readTodayAqi(prefs, DateTime.now())!;
    expect(a.aqi, 135);
    expect(a.isBad, isTrue);
    expect(a.place['uz'], 'Toshkent');

    await prefs.setString(
      todayAqiKey,
      _aqi(135, age: const Duration(hours: 7)),
    );
    expect(readTodayAqi(prefs, DateTime.now()), isNull);
    await prefs.setString(todayAqiKey, 'not json');
    expect(readTodayAqi(prefs, DateTime.now()), isNull);
    await prefs.setString(todayAqiKey, _aqi(100));
    expect(readTodayAqi(prefs, DateTime.now())!.isBad, isFalse);
  });

  group('adjustForAir', () {
    TodayAqi aqi(int v) => TodayAqi(aqi: v, at: DateTime(2026, 11, 21, 9));
    const run = PlanParams(type: WorkoutType.run, goal: WorkoutGoal.endurance);

    test('AQI ≤ 100 or unknown: nothing changes', () {
      for (final a in [null, aqi(58), aqi(100)]) {
        final r = adjustForAir(run, a);
        expect(r.params, run);
        expect(r.homeForAir, isFalse);
        expect(adjustForAir(const PlanParams(), a).homeForAir, isFalse);
      }
    });

    test('AQI 101: an outdoor sport becomes «at home», the rest stays', () {
      final r = adjustForAir(run, aqi(101));
      expect(r.homeForAir, isTrue);
      expect(r.params.type, WorkoutType.home);
      expect(r.params.goal, WorkoutGoal.endurance);
      expect(r.params.daysPerWeek, run.daysPerWeek);
    });

    test('AQI > 100, no plan yet (defaults): the generator picks home', () {
      final r = adjustForAir(const PlanParams(), aqi(156));
      expect(r.homeForAir, isTrue);
      expect(r.params.type, WorkoutType.home);
    });

    test('AQI > 100: indoor sports the user chose are kept', () {
      for (final t in [
        WorkoutType.gym,
        WorkoutType.yoga,
        WorkoutType.swim,
        WorkoutType.kurash,
      ]) {
        final p = PlanParams(type: t, goal: WorkoutGoal.gain);
        final r = adjustForAir(p, aqi(156));
        expect(r.params, p, reason: t.name);
        expect(r.homeForAir, isFalse, reason: t.name);
      }
    });
  });

  testWidgets('AQI > 100: the generator picks «at home» by itself', (
    tester,
  ) async {
    await _pump(tester, {todayAqiKey: _aqi(135)});
    expect(find.byKey(const Key('workouts-air-banner')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('workouts-air-text'))).data,
      'Havo ifloslangan (AQI 135, Toshkent) — bugun uyda mashq qiling',
    );
    expect(_selected(tester, 'workouts-type-home'), isTrue);

    // Running anyway → a warning with a one-tap way back home.
    await tester.tap(find.byKey(const Key('workouts-type-run')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('workouts-air-text'))).data,
      contains('yugurish tavsiya etilmaydi'),
    );
    await tester.tap(find.byKey(const Key('workouts-air-home')));
    await tester.pumpAndSettle();
    expect(_selected(tester, 'workouts-type-home'), isTrue);
    expect(find.byKey(const Key('workouts-air-home')), findsNothing);
  });

  testWidgets('clean air or stale AQI: no banner', (tester) async {
    await _pump(tester, {todayAqiKey: _aqi(58)});
    expect(find.byKey(const Key('workouts-air-banner')), findsNothing);
    await _pump(tester, {
      todayAqiKey: _aqi(160, age: const Duration(hours: 8)),
    });
    expect(find.byKey(const Key('workouts-air-banner')), findsNothing);
  });

  testWidgets('a running plan on a bad-air day: warning → home plan', (
    tester,
  ) async {
    const plan = WorkoutPlan(
      id: 'p',
      params: {'type': 'run', 'goal': 'endurance', 'days': 3},
      days: [PlanDay(day: 1, weekday: 1, items: [], minutes: 30, kcal: 300)],
    );
    await _pump(tester, {
      todayAqiKey: _aqi(135),
      FakeWorkoutsRepository.planKey: jsonEncode(plan.toJson()),
    });
    expect(find.byKey(const Key('workouts-plan-air-warning')), findsOneWidget);
    await tester.tap(find.byKey(const Key('workouts-plan-air-home')));
    await tester.pumpAndSettle();
    // The generator sheet: «run» replaced with «at home».
    expect(_selected(tester, 'workouts-type-home'), isTrue);
    expect(find.byKey(const Key('workouts-air-banner')), findsOneWidget);
  });
}
