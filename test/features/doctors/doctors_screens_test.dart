import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/doctors/application/doctors_providers.dart';
import 'package:sino/features/doctors/data/models.dart';
import 'package:sino/features/doctors/doctors_feature.dart';
import 'package:sino/features/doctors/presentation/appointments_screen.dart';
import 'package:sino/features/doctors/presentation/doctor_screen.dart';
import 'package:sino/features/doctors/presentation/doctors_paths.dart';
import 'package:sino/features/doctors/presentation/doctors_screen.dart';

import '../../helpers/test_app.dart';

const _karimova = 'a4000000-0000-4000-8000-000000000001';
const _aliyev = 'a4000000-0000-4000-8000-000000000002'; // offline, terapevt

/// Fixed clock: Tuesday morning — today still has free slots, so results
/// don't depend on when the suite runs.
final _morning = DateTime(2026, 11, 24, 8, 15);

/// Saturday late evening: today is over, tomorrow is Sunday (day off).
final _lateSaturday = DateTime(2026, 11, 28, 23, 50);

List<Override> _overrides(SharedPreferences prefs, {DateTime? now}) => [
  ...appOverrides(prefs: prefs, useFake: true),
  doctorsClockProvider.overrideWithValue(() => now ?? _morning),
];

class _Harness {
  late GoRouter router;
  late ProviderContainer container;
}

Future<_Harness> _pumpRouter(
  WidgetTester tester,
  String location, {
  AppLang lang = AppLang.uz,
  DateTime? now,
}) async {
  final h = _Harness();
  final prefs = await fakePrefs(signedIn: true);
  h.router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: location,
    routes: doctorsRoutes,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(prefs, now: now),
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: lang.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: h.router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  h.container = ProviderScope.containerOf(
    tester.element(find.byType(Navigator).first),
  );
  return h;
}

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// A selectable time-slot chip («10:30»).
final _freeSlot = find.byWidgetPredicate(
  (w) =>
      w is ChoiceChip &&
      w.onSelected != null &&
      w.label is Text &&
      RegExp(r'^\d\d:\d\d$').hasMatch((w.label as Text).data ?? ''),
);

void main() {
  group('catalog', () {
    testWidgets('specialty chips are translated and filter', (tester) async {
      await _pumpRouter(tester, AppRoutes.doctors);
      final chip = find.widgetWithText(ChoiceChip, 'Kardiolog');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Akmal Tursunov'), findsOneWidget);
      expect(find.text('Dilnoza Karimova'), findsNothing);
      expect(find.text('Shifokorlar: 2'), findsOneWidget);
    });

    testWidgets('labels in Russian and English', (tester) async {
      await _pumpRouter(tester, AppRoutes.doctors, lang: AppLang.ru);
      final chip = find.widgetWithText(ChoiceChip, 'Терапевт');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Врачей: 3'), findsOneWidget);
      expect(find.textContaining('Терапевт · Стаж'), findsWidgets);
    });

    testWidgets('search and the online filter', (tester) async {
      await _pumpRouter(tester, AppRoutes.doctors);
      await tester.enterText(find.byType(TextField), 'aliyev');
      await tester.pumpAndSettle();
      expect(find.text('Rustam Aliyev'), findsOneWidget);
      expect(find.text('Shifokorlar: 1'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Onlayn'));
      await tester.pumpAndSettle();
      expect(find.text('Shifokor topilmadi'), findsOneWidget);

      await tester.tap(find.byTooltip('Tozalash'));
      await tester.pumpAndSettle();
      expect(find.text('Shifokorlar: 9'), findsOneWidget);
    });

    testWidgets('tap opens the doctor', (tester) async {
      await _pumpRouter(tester, AppRoutes.doctors);
      await _scrollTo(tester, find.text('Rustam Aliyev'));
      await tester.tap(find.text('Rustam Aliyev'));
      await tester.pumpAndSettle();
      expect(find.byType(DoctorScreen), findsOneWidget);
      expect(find.text('Shifokor maslahatini almashtirmaydi'), findsOneWidget);
    });
  });

  group('booking', () {
    testWidgets('pick a slot for a family member → appointment', (
      tester,
    ) async {
      final h = await _pumpRouter(tester, DoctorsPaths.doctor(_aliyev));
      // Offline doctor: no visit type switch.
      expect(find.text('Qabul turi'), findsNothing);
      final confirm = find.ancestor(
        of: find.text('Vaqtni tanlang'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      await _scrollTo(tester, confirm);
      expect(tester.widget<ButtonStyleButton>(confirm).onPressed, isNull);

      await _scrollTo(tester, find.widgetWithText(ChoiceChip, 'Malika'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Malika'));
      await tester.pump();
      await _scrollTo(tester, _freeSlot.first);
      final label =
          (tester.widget<ChoiceChip>(_freeSlot.first).label as Text).data!;
      await tester.tap(_freeSlot.first);
      await tester.pump();

      final book = find.textContaining('Yozilish ·');
      expect(find.textContaining(label), findsWidgets);
      await _scrollTo(tester, book);
      await tester.tap(book);
      await tester.pumpAndSettle();
      expect(find.textContaining('Qabulga yozildingiz:'), findsOneWidget);

      final appts = h.container.read(appointmentsProvider).requireValue;
      final mine = appts.where((a) => a.doctorId == _aliyev).single;
      expect(mine.memberId, 'fake-daughter');
      expect(mine.online, isFalse);
      expect(mine.status, AppointmentStatus.booked);

      h.router.push(DoctorsPaths.appointments);
      await tester.pumpAndSettle();
      expect(find.text('Rustam Aliyev'), findsOneWidget);
    });

    testWidgets('online visit with an online doctor', (tester) async {
      final h = await _pumpRouter(tester, DoctorsPaths.doctor(_karimova));
      await _scrollTo(tester, find.text('Qabul turi'));
      await tester.tap(find.widgetWithText(SegmentedButton<bool>, 'Onlayn'));
      await tester.pump();
      await _scrollTo(tester, _freeSlot.first);
      await tester.tap(_freeSlot.first);
      await tester.pump();
      final book = find.textContaining('Yozilish ·');
      await _scrollTo(tester, book);
      await tester.tap(book);
      await tester.pumpAndSettle();
      final appts = h.container.read(appointmentsProvider).requireValue;
      expect(
        appts.where(
          (a) => a.doctorId == _karimova && a.online && a.isUpcoming(_morning),
        ),
        isNotEmpty,
      );
    });

    testWidgets('late Saturday evening: first day is Monday', (tester) async {
      await _pumpRouter(
        tester,
        DoctorsPaths.doctor(_aliyev),
        now: _lateSaturday,
      );
      // Today (Saturday) is over and Sunday is a day off → Monday.
      final today = find.widgetWithText(ChoiceChip, 'Bugun');
      expect(tester.widget<ChoiceChip>(today).selected, isFalse);
      expect(find.widgetWithText(ChoiceChip, 'Ertaga'), findsNothing);
      await _scrollTo(tester, find.text('Vaqtni tanlang'));
      expect(_freeSlot, findsWidgets);
    });

    testWidgets('unknown doctor', (tester) async {
      await _pumpRouter(tester, DoctorsPaths.doctor('nope'));
      expect(find.text('Shifokor topilmadi'), findsOneWidget);
    });
  });

  testWidgets('appointments: upcoming, past, cancel', (tester) async {
    await _pumpRouter(tester, DoctorsPaths.appointments);
    expect(find.byType(AppointmentsScreen), findsOneWidget);
    expect(find.text('Kelgusi'), findsOneWidget);
    expect(find.text('Dilnoza Karimova'), findsOneWidget);
    expect(find.text('Akbar'), findsOneWidget); // Tursunov, for the father
    await _scrollTo(tester, find.text('Bo‘lib o‘tdi'));
    expect(find.text('Nodira Yusupova'), findsOneWidget);

    await _scrollTo(tester, find.text('Dilnoza Karimova'));
    await tester.tap(find.widgetWithText(TextButton, 'Bekor qilish').first);
    await tester.pumpAndSettle();
    expect(find.text('Yozuvni bekor qilasizmi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Bekor qilish'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Bekor qilingan'));
    expect(find.text('Bekor qilingan'), findsOneWidget);
  });

  testWidgets('home card shows the nearest appointment', (tester) async {
    final prefs = await fakePrefs(signedIn: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(prefs),
        child: MaterialApp(
          locale: AppLang.uz.locale,
          supportedLocales: AppLang.locales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Builder(builder: doctorsHomeCards.single.builder),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Karimova (terapevt) in 2 days at 10:30.
    expect(find.textContaining('10:30 · Terapevt'), findsOneWidget);
  });

  final screens = <String, Widget Function()>{
    'catalog': () => const DoctorsScreen(),
    'doctor': () => const DoctorScreen(doctorId: _karimova),
    'appointments': () => const AppointmentsScreen(),
    'home card': () => Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [Builder(builder: doctorsHomeCards.single.builder)],
      ),
    ),
  };
  for (final MapEntry(key: name, value: build) in screens.entries) {
    for (final lang in AppLang.values) {
      for (final dark in [false, true]) {
        testWidgets('$name · ${lang.name} · ${dark ? 'dark' : 'light'}', (
          tester,
        ) async {
          // Smallest common phone + enlarged system font.
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final prefs = await fakePrefs(signedIn: true);
          await tester.pumpWidget(
            ProviderScope(
              overrides: _overrides(prefs),
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                locale: lang.locale,
                supportedLocales: AppLang.locales,
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: build(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
