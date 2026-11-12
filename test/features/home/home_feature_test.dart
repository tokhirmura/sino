import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/app/app.dart';
import 'package:sino/app/router.dart';
import 'package:sino/core/backend/backend.dart';
import 'package:sino/core/contracts/home_card.dart';
import 'package:sino/core/data/user.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/home/application/health_index.dart';
import 'package:sino/features/doctors/presentation/doctors_screen.dart';
import 'package:sino/features/home/home_feature.dart';
import 'package:sino/features/home/presentation/home_screen.dart';
import 'package:sino/features/home/presentation/widgets/services_grid.dart';

import '../../helpers/test_app.dart';

/// Tall phone so the whole (lazy) home list is built.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _year = 2026;

UserProfile _profile({
  int born = _year - 29,
  double height = 178,
  double weight = 76,
  String? bloodType,
}) => UserProfile(
  id: 'u',
  fullName: 'Aziz',
  birthYear: born,
  heightCm: height,
  weightKg: weight,
  bloodType: bloodType,
);

void main() {
  test('home exposes its root route', () {
    final paths = [for (final r in homeRoutes.whereType<GoRoute>()) r.path];
    expect(paths, contains(AppRoutes.home));
  });

  group('health index v1', () {
    test('healthy profile with blood type → 90 (activity is neutral)', () {
      final i = HealthIndex.fromProfile(
        _profile(bloodType: 'A(II) Rh+'),
        currentYear: _year,
      )!;
      expect(i.bmi, closeTo(23.99, 0.01));
      expect(i.bmiCategory, BmiCategory.normal);
      expect(i.score, 90);
      expect(i.tips, [HealthTip.startActivity]);
    });

    test('questionnaire only (no blood type) → 70 and a tip to add it', () {
      final i = HealthIndex.fromProfile(_profile(), currentYear: _year)!;
      expect(i.score, 70);
      expect(i.tips.first, HealthTip.addBloodType);
    });

    test('overweight and older score lower, tip about weight first', () {
      final i = HealthIndex.fromProfile(
        _profile(born: _year - 60, height: 170, weight: 95),
        currentYear: _year,
      )!;
      // BMI 32.87 → 40 − 7.87·4 ≈ 9; age 60 → 20 − 12 = 8; +0 +10.
      expect(i.bmiCategory, BmiCategory.obese);
      expect(i.parts.first.points, 9);
      expect(i.parts[1].points, 8);
      expect(i.score, 27);
      expect(i.tips.first, HealthTip.lowerWeight);
    });

    test('underweight → tip to gain weight', () {
      final i = HealthIndex.fromProfile(
        _profile(height: 180, weight: 55),
        currentYear: _year,
      )!;
      expect(i.bmiCategory, BmiCategory.under);
      expect(i.tips.first, HealthTip.gainWeight);
    });

    test('incomplete profile → no index', () {
      const p = UserProfile(id: 'u', fullName: 'Aziz');
      expect(HealthIndex.fromProfile(p), isNull);
    });

    test('maxes add up to 100', () {
      expect(IndexFactor.values.fold(0, (s, f) => s + f.max), 100);
    });
  });

  test('first name for the greeting', () {
    expect(firstName('Aziz Karimov'), 'Aziz');
    expect(firstName('  Madina  '), 'Madina');
    expect(firstName(''), '');
  });

  test('quick services cover every feature screen', () {
    expect(quickServiceRoutes.toSet(), {
      AppRoutes.pharmacy,
      AppRoutes.nutrition,
      AppRoutes.workouts,
      AppRoutes.reminders,
      AppRoutes.doctors,
      AppRoutes.vitals,
      AppRoutes.weather,
      AppRoutes.sos,
      AppRoutes.assistant,
    });
  });

  testWidgets('home: greeting, index, services and feature cards', (
    tester,
  ) async {
    _tallView(tester);
    await pumpScreen(tester, const HomeScreen());
    expect(find.text('Salom, Aziz'), findsOneWidget);
    expect(find.text('Bugungi salomatlik indeksi'), findsOneWidget);
    expect(find.byKey(const ValueKey('health-index-score')), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
    expect(find.text('Shifokor maslahatini almashtirmaydi'), findsOneWidget);
    expect(find.text('Xizmatlar'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('service-${AppRoutes.vitals}')),
      findsOneWidget,
    );
    expect(find.text('Siz uchun'), findsOneWidget);
    // Pharmacy: grid tile + the pharmacy feature's card.
    expect(find.text('Dorixona'), findsNWidgets(2));
  });

  testWidgets('tap on the index opens the breakdown', (tester) async {
    _tallView(tester);
    await pumpScreen(tester, const HomeScreen());
    await tester.tap(find.text('Bugungi salomatlik indeksi'));
    await tester.pumpAndSettle();
    expect(find.text('Indeks qanday hisoblanadi'), findsOneWidget);
    expect(find.text('20 / 20'), findsWidgets);
  });

  testWidgets('no feature cards → home still works', (tester) async {
    _tallView(tester);
    final prefs = await fakePrefs(signedIn: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          useFakeProvider.overrideWithValue(true),
          homeCardsProvider.overrideWithValue(const []),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: AppLang.uz.locale,
          supportedLocales: AppLang.locales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Xizmatlar'), findsOneWidget);
    expect(find.text('Siz uchun'), findsNothing);
  });

  testWidgets('service tile opens its screen', (tester) async {
    _tallView(tester);
    await pumpSinoApp(tester, signedIn: true);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SinoApp)),
    );
    String location() => container
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;

    await tester.tap(
      find.byKey(const ValueKey('service-${AppRoutes.doctors}')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DoctorsScreen), findsOneWidget);

    container.read(routerProvider).go(AppRoutes.home);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('service-${AppRoutes.nutrition}')),
    );
    await tester.pumpAndSettle();
    expect(location(), AppRoutes.nutrition);
  });
}
