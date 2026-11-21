import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/core/widgets/primary_button.dart';
import 'package:sino/features/pharmacy/application/pharmacy_providers.dart';
import 'package:sino/features/pharmacy/data/models.dart';
import 'package:sino/features/pharmacy/data/external_launcher.dart';
import 'package:sino/features/pharmacy/data/rx_photo.dart';
import 'package:sino/features/pharmacy/pharmacy_feature.dart';
import 'package:sino/features/pharmacy/presentation/medicine_screen.dart';
import 'package:sino/features/pharmacy/presentation/pharmacies_screen.dart';
import 'package:sino/features/pharmacy/presentation/pharmacy_paths.dart';
import 'package:sino/features/pharmacy/presentation/pharmacy_screen.dart';
import 'package:sino/features/pharmacy/presentation/reservations_screen.dart';
import 'package:sino/features/pharmacy/presentation/scan_screen.dart';
import 'package:sino/features/pharmacy/presentation/widgets/reservation_steps.dart';

import '../../helpers/test_app.dart';

// Fixed catalog ids (assets/pharmacy/medicines.json).
const _paracetamol = 'a1000000-0000-4000-8000-000000000001';
const _loratadine = 'a1000000-0000-4000-8000-000000000023';
const _amoxicillin = 'a1000000-0000-4000-8000-000000000020';

class _FakePicker implements RxPhotoPicker {
  final calls = <RxPhotoSource>[];

  @override
  Future<String?> pick(RxPhotoSource source) async {
    calls.add(source);
    return '/no/such/dir/rx.jpg';
  }
}

class _Harness {
  final picker = _FakePicker();
  final launched = <Uri>[];
  late GoRouter router;
  late ProviderContainer container;
}

/// The pharmacy routes under a root GoRouter (as in the app), fake mode.
Future<_Harness> _pumpRouter(
  WidgetTester tester,
  String location, {
  bool dark = false,
  AppLang lang = AppLang.uz,
}) async {
  final h = _Harness();
  final prefs = await fakePrefs(signedIn: true);
  h.router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: location,
    routes: pharmacyRoutes,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appOverrides(prefs: prefs, useFake: true),
        pharmacyMapTilesProvider.overrideWithValue(false),
        rxPhotoPickerProvider.overrideWithValue(h.picker),
        pharmacyLauncherProvider.overrideWithValue((uri) async {
          h.launched.add(uri);
          return true;
        }),
      ],
      child: MaterialApp.router(
        theme: dark ? AppTheme.dark : AppTheme.light,
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

void main() {
  group('search', () {
    testWidgets('typing searches name, Cyrillic and symptoms', (tester) async {
      await _pumpRouter(tester, AppRoutes.pharmacy);
      await tester.enterText(find.byType(TextField), 'ибупрофен');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Ibuprofen 400 mg'), findsOneWidget);
      expect(find.text('Amlodipin 5 mg'), findsNothing);

      await tester.enterText(find.byType(TextField), 'qwertyzz');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Hech narsa topilmadi'), findsOneWidget);

      await tester.tap(find.byTooltip('Tozalash'));
      await tester.pumpAndSettle();
      expect(find.text('Barcha dorilar'), findsOneWidget);
    });

    testWidgets('a barcode typed in search finds the medicine', (tester) async {
      await _pumpRouter(tester, AppRoutes.pharmacy);
      await tester.enterText(find.byType(TextField), '4781000000011');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Paracetamol 500 mg'), findsOneWidget);
    });

    testWidgets('category chips filter the list', (tester) async {
      await _pumpRouter(tester, AppRoutes.pharmacy);
      final chip = find.widgetWithText(ChoiceChip, 'Allergiya');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Loratadin 10 mg'), findsOneWidget);
      expect(find.text('Amlodipin 5 mg'), findsNothing);
    });

    testWidgets('tap opens the medicine; a new ?q= replaces the query', (
      tester,
    ) async {
      final h = await _pumpRouter(tester, AppRoutes.pharmacy);
      await _scrollTo(tester, find.text('Amlodipin 5 mg'));
      await tester.tap(find.text('Amlodipin 5 mg'));
      await tester.pumpAndSettle();
      expect(find.byType(MedicineScreen), findsOneWidget);

      h.router.go(AppRoutes.pharmacySearch('loratadin'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'loratadin'), findsOneWidget);
      expect(find.text('Klaritin 10 mg'), findsOneWidget);
    });
  });

  group('medicine', () {
    testWidgets('details, disclaimer, prices and analogs', (tester) async {
      await _pumpRouter(tester, PharmacyPaths.medicine(_paracetamol));
      expect(find.text('Paracetamol 500 mg'), findsOneWidget);
      expect(find.text('Shifokor maslahatini almashtirmaydi'), findsOneWidget);
      // Big badge in the header (+ compact ones on OTC analogs).
      expect(find.text('Retseptsiz'), findsWidgets);
      expect(find.text('Retsept kerak'), findsNothing);
      expect(find.textContaining('Isitma va o‘rtacha'), findsOneWidget);
      expect(find.textContaining('Sutkalik dozadan'), findsOneWidget);
      await _scrollTo(tester, find.textContaining('ta dorixonada bor'));
      expect(find.widgetWithText(FilledButton, 'Bron qilish'), findsWidgets);
      await _scrollTo(tester, find.text('Panadol 500 mg'));
      expect(find.text('Efferalgan 500 mg'), findsOneWidget);
    });

    testWidgets('unknown id shows «not found»', (tester) async {
      await _pumpRouter(tester, PharmacyPaths.medicine('nope'));
      expect(find.text('Dori topilmadi'), findsOneWidget);
    });
  });

  group('reservations', () {
    testWidgets('reserve → pending → ready after the fake pharmacy timer', (
      tester,
    ) async {
      final h = await _pumpRouter(tester, PharmacyPaths.medicine(_loratadine));
      await _scrollTo(tester, find.textContaining('ta dorixonada bor'));
      final reserve = find.widgetWithText(FilledButton, 'Bron qilish').first;
      await _scrollTo(tester, reserve);
      await tester.tap(reserve);
      await tester.pumpAndSettle();
      expect(find.text('Kim uchun'), findsOneWidget);
      expect(find.text('Retsept rasmi (ixtiyoriy)'), findsOneWidget);

      // For a family member.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Dilfuza'));
      await tester.pump();
      await tester.tap(find.textContaining('Bron qilish ·'));
      await tester.pumpAndSettle();
      expect(find.text('Bron qilindi: Loratadin 10 mg'), findsOneWidget);

      h.router.push(PharmacyPaths.reservations);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(ReservationsScreen), findsOneWidget);
      // 3-step bar: accepted, now «Tayyorlanmoqda».
      final steps = find.byType(ReservationSteps);
      expect(steps, findsWidgets);
      expect(find.text('Qabul qilindi'), findsWidgets);
      expect(find.text('Tayyorlanmoqda'), findsWidgets);
      expect(find.text('Dilfuza'), findsOneWidget);
      Reservation loratadin() => h.container
          .read(reservationsProvider)
          .requireValue
          .firstWhere((r) => r.forMemberId == 'fake-mother');
      expect(reservationProgress(loratadin()), 1);

      // The fake pharmacy prepares it → full-screen celebration.
      await tester.pump(const Duration(seconds: 21));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(reservationProgress(loratadin()), 3);
      expect(
        find.byKey(const ValueKey('reservation-ready-celebration')),
        findsOneWidget,
      );
      expect(find.text('Bron tayyor! 🎉'), findsOneWidget);
      expect(
        find.text('Loratadin 10 mg olib ketishga tayyor!'),
        findsOneWidget,
      );
      expect(find.byType(ConfettiWidget), findsOneWidget);
      // `confetti` moves particles by the real `DateTime.now()`, which the
      // test clock doesn't advance — it never settles here. Close the
      // banner first, then settle.
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Ajoyib!'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('reservation-ready-celebration')),
        findsNothing,
      );
    });

    testWidgets('prescription medicine needs a photo, kept on the device', (
      tester,
    ) async {
      final h = await _pumpRouter(tester, PharmacyPaths.medicine(_amoxicillin));
      expect(find.text('Retsept kerak'), findsOneWidget);
      await _scrollTo(tester, find.textContaining('ta dorixonada bor'));
      final reserve = find.widgetWithText(FilledButton, 'Bron qilish').first;
      await _scrollTo(tester, reserve);
      await tester.tap(reserve);
      await tester.pumpAndSettle();

      expect(find.text('Retsept rasmi (majburiy)'), findsOneWidget);
      final confirm = find.byKey(const ValueKey('reserve-confirm'));
      expect(tester.widget<PrimaryButton>(confirm).onPressed, isNull);

      await tester.tap(find.text('Kamera'));
      await tester.pumpAndSettle();
      expect(h.picker.calls, [RxPhotoSource.camera]);
      expect(find.text('Retsept biriktirildi'), findsOneWidget);
      expect(tester.widget<PrimaryButton>(confirm).onPressed, isNotNull);

      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final photos = h.container.read(rxPhotosProvider);
      expect(photos.values, contains('/no/such/dir/rx.jpg'));
    });

    testWidgets('cancel a ready reservation; directions open maps', (
      tester,
    ) async {
      final h = await _pumpRouter(tester, PharmacyPaths.reservations);
      expect(find.text('Faol'), findsOneWidget);
      expect(find.text('Tarix'), findsOneWidget);
      // The active (ready) one shows the full 3-step bar.
      expect(find.byType(ReservationSteps), findsOneWidget);
      expect(find.text('Tayyor'), findsOneWidget);
      expect(find.text('Olib ketilgan'), findsOneWidget);

      await tester.tap(find.text('Yo‘nalish'));
      await tester.pumpAndSettle();
      expect(h.launched.single.host, 'maps.google.com');

      await tester.tap(find.widgetWithText(TextButton, 'Bekor qilish'));
      await tester.pumpAndSettle();
      expect(find.text('Bronni bekor qilasizmi?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Bekor qilish'));
      await tester.pumpAndSettle();
      expect(find.text('Bekor qilingan'), findsOneWidget);
      expect(find.text('Faol'), findsNothing);
    });
  });

  group('pharmacies', () {
    testWidgets('list nearest first, 24/7 filter, details sheet', (
      tester,
    ) async {
      final h = await _pumpRouter(tester, PharmacyPaths.pharmacies);
      expect(find.text('Davo plyus'), findsOneWidget);
      expect(find.textContaining(' km'), findsWidgets);

      await tester.tap(find.widgetWithText(FilterChip, '24/7'));
      await tester.pumpAndSettle();
      expect(find.text('Davo plyus'), findsNothing);
      expect(find.text('Shifo dorixonasi'), findsOneWidget);

      await tester.tap(find.text('Shifo dorixonasi'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Yo‘nalish'));
      await tester.pumpAndSettle();
      expect(h.launched.single.query, contains('41.27560'));
    });

    testWidgets('map view shows a marker per pharmacy (no tiles)', (
      tester,
    ) async {
      final h = await _pumpRouter(tester, PharmacyPaths.pharmacies);
      await tester.tap(find.text('Xarita'));
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);
      final pins = find.byType(PharmacyPin);
      expect(pins, findsWidgets);
      expect(find.byKey(const ValueKey('no-selection')), findsOneWidget);
      await tester.tap(pins.first);
      await tester.pump();
      // The card slides up from the bottom.
      final card = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('selected-'),
      );
      expect(card, findsOneWidget);
      expect(find.byType(SlideTransition), findsWidgets);
      await tester.pumpAndSettle();
      expect(tester.widget<PharmacyPin>(pins.first).selected, isTrue);
      await tester.tap(find.text('Yo‘nalish'));
      await tester.pumpAndSettle();
      expect(h.launched, hasLength(1));
      await tester.tap(find.byTooltip('Yopish'));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
    });
  });

  testWidgets('scanner: the code can be typed when there is no camera', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLang.uz.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => const ScanScreen(useCamera: false),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.text('Kamera mavjud emas. Kodni qo‘lda kiriting.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Kodni qo‘lda kiritish'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' 4781000000011 ');
    await tester.tap(find.text('Qidirish'));
    await tester.pumpAndSettle();
    expect(result, '4781000000011');
  });

  group('home card', () {
    testWidgets('shows ready reservations', (tester) async {
      final prefs = await fakePrefs(signedIn: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(prefs: prefs, useFake: true),
          child: MaterialApp(
            locale: AppLang.uz.locale,
            supportedLocales: AppLang.locales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: Builder(builder: pharmacyHomeCards.single.builder),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Olib ketishga tayyor: 1'), findsOneWidget);
    });
  });

  // Every pharmacy screen in uz / ru / en × light / dark on a small phone:
  // no overflow or other exceptions.
  final screens = <String, Widget Function()>{
    'search': () => const PharmacyScreen(),
    'search with query': () => const PharmacyScreen(initialQuery: 'para'),
    'medicine': () => const MedicineScreen(medicineId: _amoxicillin),
    'pharmacies': () => const PharmaciesScreen(),
    'reservations': () => const ReservationsScreen(),
    'home card': () => Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [Builder(builder: pharmacyHomeCards.single.builder)],
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
              overrides: appOverrides(prefs: prefs, useFake: true),
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
