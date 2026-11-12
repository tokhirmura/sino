import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/sos/application/sos_controller.dart';
import 'package:sino/features/sos/data/first_aid.dart';
import 'package:sino/features/sos/data/location_repository.dart';
import 'package:sino/features/sos/presentation/first_aid_screen.dart';
import 'package:sino/features/sos/presentation/sos_screen.dart';
import 'package:sino/features/sos/sos_feature.dart';

import '../../helpers/test_app.dart';

/// SOS screen (fake mode) with a recording launcher; returns opened URIs.
Future<List<Uri>> _pump(
  WidgetTester tester, {
  Widget screen = const SosScreen(),
  bool launchOk = true,
}) async {
  tester.view.physicalSize = const Size(412, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <Uri>[];
  final prefs = await fakePrefs(signedIn: true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appOverrides(prefs: prefs, useFake: true),
        externalLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return launchOk;
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: AppLang.uz.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

Future<void> _hold(WidgetTester tester, Duration d) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(const ValueKey('sos-hold-button'))),
  );
  for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await gesture.up();
}

void main() {
  test('sos exposes its root route and first-aid sub-route', () {
    final root = sosRoutes.whereType<GoRoute>().single;
    expect(root.path, AppRoutes.sos);
    expect(
      [for (final r in root.routes.whereType<GoRoute>()) r.path],
      ['first-aid/:id'],
    );
  });

  test(
    'first aid asset: 6 guides, steps in uz/ru/en of equal length',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final raw = await rootBundle.loadString(firstAidAsset, cache: false);
      final guides = [
        for (final m in jsonDecode(raw) as List)
          FirstAidGuide.fromMap(m as Map<String, dynamic>),
      ];
      expect(guides, hasLength(6));
      expect({for (final g in guides) g.id}, hasLength(6));
      for (final g in guides) {
        for (final map in [g.title, g.when]) {
          expect(map.keys, containsAll(['uz', 'ru', 'en']), reason: g.id);
        }
        final n = g.stepsFor('uz').length;
        expect(n, greaterThanOrEqualTo(3), reason: g.id);
        expect(g.stepsFor('ru'), hasLength(n), reason: g.id);
        expect(g.stepsFor('en'), hasLength(n), reason: g.id);
      }
    },
  );

  test('tel: only fills the number; SMS body is %-encoded', () {
    expect(telUri('103').toString(), 'tel:103');
    final sms = smsUri('SOS! Joylashuvim: https://maps.google.com/?q=1,2');
    expect(sms.toString(), startsWith('sms:?body=SOS!%20Joylashuvim'));
    expect(sms.toString(), isNot(contains('+')));
  });

  testWidgets('short press does nothing; 2 s hold sends the alert', (
    tester,
  ) async {
    final opened = await _pump(tester);
    await _hold(tester, const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sos-alert-result')), findsNothing);

    await _hold(tester, const Duration(milliseconds: 2200));
    expect(
      find.text('Joylashuv aniqlanmoqda va yuborilmoqda…'),
      findsOneWidget,
    );
    await tester.pump(SosAlertNotifier.sendDelay);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sos-alert-result')), findsOneWidget);
    expect(find.text('Yaqinlaringizga yuborildi (demo)'), findsOneWidget);
    expect(find.text('Dilfuza, Akbar, Malika'), findsOneWidget);
    expect(find.text('📍 41.31108, 69.27976'), findsOneWidget);

    await tester.tap(find.text('SMS yuborish'));
    await tester.pumpAndSettle();
    final sms = Uri.decodeComponent(opened.single.toString());
    expect(sms, contains(FakeLocationRepository.tashkent.mapsUrl));
    expect(sms, contains('Qon guruhi: A(II) Rh+'));
    expect(sms, contains('Allergiya: Penitsillin'));

    await tester.tap(find.byTooltip('Yopish'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sos-alert-result')), findsNothing);
  });

  testWidgets('quick dial opens the dialer with the number', (tester) async {
    final opened = await _pump(tester);
    for (final n in ['103', '101', '102', '104']) {
      await tester.tap(find.byKey(ValueKey('dial-$n')));
      await tester.pumpAndSettle();
    }
    expect(
      [for (final u in opened) u.toString()],
      ['tel:103', 'tel:101', 'tel:102', 'tel:104'],
    );
  });

  testWidgets('no dialer → hint to dial manually', (tester) async {
    await _pump(tester, launchOk: false);
    await tester.tap(find.byKey(const ValueKey('dial-103')));
    await tester.pumpAndSettle();
    expect(
      find.text('Qo‘ng‘iroq ochilmadi — 103 raqamini qo‘lda tering.'),
      findsOneWidget,
    );
  });

  testWidgets('medical info and 6 first-aid guides offline', (tester) async {
    await _pump(tester);
    expect(find.text('Aziz, 29 yosh'), findsOneWidget);
    expect(find.text('Yurak to‘xtashi (reanimatsiya)'), findsOneWidget);
    expect(find.text('Issiq urishi'), findsOneWidget);
    expect(find.textContaining('Shifokor maslahatini'), findsOneWidget);
  });

  testWidgets('first aid guide: numbered steps and a 103 button', (
    tester,
  ) async {
    final opened = await _pump(tester, screen: const FirstAidScreen(id: 'cpr'));
    expect(find.text('Yurak to‘xtashi (reanimatsiya)'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.textContaining('100–120 marta'), findsOneWidget);
    await tester.tap(find.text('103 — Tez yordam'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'tel:103');
  });

  testWidgets('home card opens SOS', (tester) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpSinoApp(tester, signedIn: true);
    await tester.tap(find.text('Tez yordam va yaqinlarga xabar'));
    await tester.pumpAndSettle();
    expect(find.byType(SosScreen), findsOneWidget);
  });
}
