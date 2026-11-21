import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/vitals/application/vitals_math.dart';
import 'package:sino/features/vitals/application/vitals_providers.dart';
import 'package:sino/features/vitals/data/models.dart';
import 'package:sino/features/vitals/data/vitals_repository.dart';
import 'package:sino/features/vitals/presentation/vitals_screen.dart';
import 'package:sino/features/vitals/vitals_feature.dart';

Future<(SharedPreferences, ProviderContainer)> _pump(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'core.fake_signed_in': true});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(prefs: prefs, useFake: true),
      child: MaterialApp(
        theme: AppTheme.light,
        locale: AppLang.uz.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const VitalsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(
    tester.element(find.byType(VitalsScreen)),
  );
  return (prefs, c);
}

String _rich(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).textSpan!.toPlainText();

Future<void> _add(
  WidgetTester tester,
  String kind,
  String v, [
  String? v2,
]) async {
  await tester.tap(find.byKey(const Key('vitals-add-fab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('vitals-add-kind-$kind')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('vitals-add-value')), v);
  if (v2 != null) {
    await tester.enterText(find.byKey(const Key('vitals-add-value2')), v2);
  }
  await tester.tap(find.byKey(const Key('vitals-add-save')));
  await tester.pumpAndSettle();
}

void main() {
  test('vitals exposes its root route', () {
    final paths = [for (final r in vitalsRoutes.whereType<GoRoute>()) r.path];
    expect(paths, contains(AppRoutes.vitals));
  });

  testWidgets('tiles, 7-day chart, add with validation, remove + undo', (
    tester,
  ) async {
    final (_, c) = await _pump(tester);

    // Demo week: latest pulse of today, chart of pulse selected.
    expect(_rich(tester, 'vitals-tile-value-pulse'), '71 zarba/daq');
    expect(find.byKey(const Key('vitals-chart-pulse')), findsOneWidget);
    expect(find.text('Umumiy me’yor: 60–100'), findsOneWidget);

    await tester.tap(find.byKey(const Key('vitals-tile-pressure')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vitals-chart-pressure')), findsOneWidget);
    expect(find.text('Sistolik (yuqori)'), findsOneWidget);

    // Out of range → error, nothing saved.
    await _add(tester, 'pulse', '500');
    expect(find.text('30–220 oralig‘ida bo‘lsin'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('vitals-add-value')), '88');
    await tester.tap(find.byKey(const Key('vitals-add-save')));
    await tester.pumpAndSettle();
    expect(_rich(tester, 'vitals-tile-value-pulse'), '88 zarba/daq');
    expect(find.byKey(const Key('vitals-chart-pulse')), findsOneWidget);

    // Diastolic above systolic → refused.
    await _add(tester, 'pressure', '120', '130');
    expect(
      find.text('Pastki bosim yuqorisidan kichik bo‘lishi kerak'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('vitals-add-value2')), '95');
    await tester.tap(find.byKey(const Key('vitals-add-save')));
    await tester.pumpAndSettle();
    expect(_rich(tester, 'vitals-tile-value-pressure'), '120/95 mm sim. ust.');
    // 95 diastolic: zone «Baland» (S2-6 zones replace «Yuqori» here).
    expect(find.text('Baland'), findsWidgets);

    // Remove the newest pressure → previous one; «Qaytarish» brings it back.
    final newest = (await c.read(vitalsWeekAllProvider.future))
        .firstWhere((v) => v.kind == VitalKind.pressure);
    await tester.tap(
      find.descendant(
        of: find.byKey(Key('vitals-entry-${newest.id}')),
        matching: find.byTooltip('O‘chirish'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      _rich(tester, 'vitals-tile-value-pressure'),
      isNot(startsWith('120/95')),
    );
    await tester.tap(find.text('Qaytarish'));
    await tester.pumpAndSettle();
    expect(_rich(tester, 'vitals-tile-value-pressure'), startsWith('120/95'));
  });

  testWidgets('BMI from the profile height and the latest weight', (
    tester,
  ) async {
    final (_, c) = await _pump(tester);
    final weight = (await c.read(vitalsWeekAllProvider.future))
        .firstWhere((v) => v.kind == VitalKind.weight)
        .value;
    expect(
      tester.widget<Text>(find.byKey(const Key('vitals-bmi-value'))).data,
      bmi(weightKg: weight, heightCm: 178)!.toStringAsFixed(1),
    );
    expect(find.byKey(const Key('vitals-bmi-level')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('vitals-bmi-weight')), '100');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('vitals-bmi-value'))).data,
      '31.6',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('vitals-bmi-level'))).data,
      'Semizlik',
    );
  });

  testWidgets('hidden «fill test history»: 5 taps → 7-day charts are full', (
    tester,
  ) async {
    final (prefs, c) = await _pump(tester);
    expect(find.byKey(const Key('vitals-fill')), findsNothing);

    // Glucose has only 2 days in the demo.
    final before = weekSeries(
      await c.read(vitalsWeekAllProvider.future),
      VitalKind.glucose,
      DateTime.now(),
    );
    expect(before.where((d) => d.value == null), isNotEmpty);

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('vitals-header')));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const Key('vitals-fill')), findsNothing);
    await tester.tap(find.byKey(const Key('vitals-header')));
    await tester.pumpAndSettle();
    expect(find.text('🧪 Dasturchi rejimi yoqildi'), findsOneWidget);
    expect(prefs.getBool(VitalsDevModeNotifier.key), isTrue);

    await tester.tap(find.byKey(const Key('vitals-fill')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ta test o‘lchovi qo‘shildi'), findsOneWidget);

    final all = await c.read(vitalsWeekAllProvider.future);
    for (final k in VitalKind.values) {
      expect(
        weekSeries(all, k, DateTime.now()).every((d) => d.value != null),
        isTrue,
        reason: k.name,
      );
    }
    // Saved, not only on screen.
    final stored =
        jsonDecode(prefs.getString(FakeVitalsRepository.listKey)!) as List;
    expect(stored.length, all.length);

    await tester.tap(find.byKey(const Key('vitals-tile-glucose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vitals-chart-glucose')), findsOneWidget);

    await tester.tap(find.byKey(const Key('vitals-fill')));
    await tester.pumpAndSettle();
    expect(find.text('Hafta allaqachon to‘liq'), findsOneWidget);

    await tester.tap(find.byKey(const Key('vitals-dev-off')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vitals-fill')), findsNothing);
  });

  testWidgets('home card: latest pulse and pressure', (tester) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'core.fake_signed_in': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(prefs: prefs, useFake: true),
        child: const SinoApp(),
      ),
    );
    await tester.pumpAndSettle();
    final values = tester
        .widget<Text>(find.byKey(const Key('vitals-home-values')))
        .data!;
    expect(values, startsWith('❤️ 71'));
    expect(values, contains('🩺 '));
    await tester.tap(find.byKey(const Key('vitals-home-card')));
    await tester.pumpAndSettle();
    expect(find.byType(VitalsScreen), findsOneWidget);
  });
}
