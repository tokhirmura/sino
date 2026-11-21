import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/backend/backend.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/vitals/application/steps.dart';
import 'package:sino/features/vitals/application/steps_providers.dart';
import 'package:sino/features/vitals/data/models.dart';
import 'package:sino/features/vitals/data/step_sensor.dart';
import 'package:sino/features/vitals/data/vitals_repository.dart';
import 'package:sino/features/vitals/presentation/widgets/steps_card.dart';

/// An empty fake vitals store (no 7-day demo), so only step rows count.
Map<String, Object> get _emptyStore => {
  FakeVitalsRepository.listKey: jsonEncode(<Object>[]),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StepsNotifier', () {
    late FakeStepSensor sensor;
    late ProviderContainer c;
    late SharedPreferences prefs;

    Future<ProviderContainer> start([
      Map<String, Object> extra = const {},
    ]) async {
      SharedPreferences.setMockInitialValues({..._emptyStore, ...extra});
      prefs = await SharedPreferences.getInstance();
      sensor = FakeStepSensor();
      c = ProviderContainer(
        overrides: [
          useFakeProvider.overrideWithValue(true),
          sharedPreferencesProvider.overrideWithValue(prefs),
          stepSensorProvider.overrideWithValue(sensor),
        ],
      );
      addTearDown(c.dispose);
      c.listen(stepsProvider, (_, _) {});
      return c;
    }

    Future<List<Vital>> stepRows() =>
        c.read(vitalsRepositoryProvider).list(kind: VitalKind.steps);

    Future<void> emit(int count) async {
      sensor.emit(count);
      await Future<void>.delayed(Duration.zero);
      await c.read(stepsProvider.notifier).idle;
    }

    test('counts today and writes one vitals row per day', () async {
      await start();
      expect(c.read(stepsProvider).status, StepsStatus.starting);

      await emit(50000); // baseline
      expect(c.read(stepsProvider), const StepsView(StepsStatus.counting, 0));
      expect(await stepRows(), isEmpty);

      await emit(50100);
      expect(c.read(stepsProvider).steps, 100);
      var rows = await stepRows();
      expect(rows, hasLength(1));
      expect(rows.single.value, 100);

      // +50 within 5 minutes — not written yet…
      await emit(50150);
      expect((await stepRows()).single.value, 100);
      // …+500 — written into the same row.
      await emit(50700);
      rows = await stepRows();
      expect(rows, hasLength(1));
      expect(rows.single.value, 700);

      // Going to the background saves the latest value at once.
      await emit(50750);
      await c.read(stepsProvider.notifier).flush();
      expect((await stepRows()).single.value, 750);
    });

    test('a row deleted by the user is created again', () async {
      await start();
      await emit(100);
      await emit(300);
      final id = (await stepRows()).single.id;
      await c.read(vitalsRepositoryProvider).remove(id);
      await emit(900);
      final rows = await stepRows();
      expect(rows, hasLength(1));
      expect(rows.single.value, 800);
      expect(rows.single.id, isNot(id));
    });

    test('yesterday from prefs is finished and saved at 23:59', () async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      await start({
        StepsNotifier.dayKey: jsonEncode(
          StepsDay(day: yesterday, baseline: 1000, lastCount: 7400).toJson(),
        ),
      });
      // Yesterday is not shown as today.
      expect(c.read(stepsProvider).steps, isNull);
      await emit(7500);
      final rows = await stepRows();
      expect(rows, hasLength(1));
      expect(rows.single.value, 6400);
      expect(
        rows.single.measuredAt,
        DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59),
      );
      expect(c.read(stepsProvider).steps, 0);
    });

    test('today from prefs is shown before the first reading', () async {
      final today = dateOnly(DateTime.now());
      await start({
        StepsNotifier.dayKey: jsonEncode(
          StepsDay(day: today, baseline: 0, lastCount: 4200).toJson(),
        ),
      });
      expect(
        c.read(stepsProvider),
        const StepsView(StepsStatus.starting, 4200),
      );
      await emit(4300);
      expect(c.read(stepsProvider).steps, 4300);
    });

    test('no sensor → unavailable; restart listens again', () async {
      await start();
      sensor.fail(const StepSensorUnavailable());
      await Future<void>.delayed(Duration.zero);
      expect(c.read(stepsProvider).status, StepsStatus.unavailable);
      c.read(stepsProvider.notifier).restart();
      expect(sensor.listens, 2);
      expect(c.read(stepsProvider).status, StepsStatus.starting);
      await emit(10);
      expect(c.read(stepsProvider).status, StepsStatus.counting);
      // Already counting — nothing to restart.
      c.read(stepsProvider.notifier).restart();
      expect(sensor.listens, 2);
    });
  });

  group('StepsCard', () {
    late FakeStepSensor sensor;

    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(_emptyStore);
      final prefs = await SharedPreferences.getInstance();
      sensor = FakeStepSensor();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...appOverrides(prefs: prefs, useFake: true),
            stepSensorProvider.overrideWithValue(sensor),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: AppLang.uz.locale,
            supportedLocales: AppLang.locales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(body: ListView(children: [child])),
          ),
        ),
      );
      await tester.pump();
    }

    String status(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('vitals-steps-status'))).data!;

    testWidgets('silence → permission hint with a settings button', (
      tester,
    ) async {
      await pump(tester, const StepsCard());
      expect(status(tester), 'Qadam sensori ulanmoqda…');
      expect(find.byKey(const Key('vitals-steps-settings')), findsNothing);

      await tester.pump(stepsSilenceLimit);
      expect(status(tester), contains('Jismoniy faollik'));
      await tester.tap(find.byKey(const Key('vitals-steps-settings')));
      await tester.pump();
      expect(sensor.settingsOpened, 1);

      // Back from the settings with the permission: listens again.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(sensor.listens, 2);
      sensor.emit(1000);
      await tester.pump();
      sensor.emit(4000);
      await tester.pumpAndSettle();
      expect(status(tester), 'Maqsadgacha 5000 qadam');
      expect(find.text('3000'), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('goal reached and the home card', (tester) async {
      await pump(tester, const StepsHomeCard());
      sensor.emit(0);
      await tester.pump();
      sensor.emit(stepsGoal + 120);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('steps-home-count'))).data,
        '${stepsGoal + 120} / $stepsGoal',
      );
      expect(find.text('Maqsad bajarildi! 🎉'), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no sensor (emulator) → a clear message', (tester) async {
      await pump(tester, const StepsCard());
      sensor.fail(const StepSensorUnavailable());
      await tester.pump();
      await tester.pump();
      expect(status(tester), contains('qadam sensori yo‘q'));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
