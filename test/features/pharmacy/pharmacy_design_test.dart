import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/theme/app_colors.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/core/widgets/widgets.dart';
import 'package:sino/features/pharmacy/application/pharmacy_providers.dart';
import 'package:sino/features/pharmacy/application/ready_celebrations.dart';
import 'package:sino/features/pharmacy/data/models.dart';
import 'package:sino/features/pharmacy/pharmacy_feature.dart';
import 'package:sino/features/pharmacy/presentation/pharmacy_screen.dart';
import 'package:sino/features/pharmacy/presentation/widgets/common.dart';
import 'package:sino/features/pharmacy/presentation/widgets/ready_celebration.dart';
import 'package:sino/features/pharmacy/presentation/widgets/reservation_steps.dart';

import '../../helpers/test_app.dart';

const _loratadine = 'a1000000-0000-4000-8000-000000000023';

Reservation _res(String id, ReservationStatus status) => Reservation(
  id: id,
  medicineId: _loratadine,
  pharmacyId: 'p',
  status: status,
);

/// Awaits [f] while pumping frames — provider futures may need the fake
/// clock to advance.
Future<T> _whilePumping<T>(WidgetTester tester, Future<T> f) async {
  var done = false;
  late T value;
  f.then((v) {
    value = v;
    done = true;
  });
  for (var i = 0; i < 100 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(done, isTrue, reason: 'future did not complete');
  return value;
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
}) async {
  final prefs = await fakePrefs(signedIn: true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(prefs: prefs, useFake: true),
      child: MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        locale: AppLang.uz.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byWidget(child)));
}

void main() {
  group('3-step progress', () {
    test('progress: sending 0, pending 1, ready 3, closed — none', () {
      expect(
        reservationProgress(_res('pending-1', ReservationStatus.pending)),
        0,
      );
      expect(reservationProgress(_res('r', ReservationStatus.pending)), 1);
      expect(reservationProgress(_res('r', ReservationStatus.ready)), 3);
      expect(reservationProgress(_res('r', ReservationStatus.picked)), isNull);
      expect(
        reservationProgress(_res('r', ReservationStatus.cancelled)),
        isNull,
      );
    });

    testWidgets('labels and step states for a pending reservation', (
      tester,
    ) async {
      await _pump(
        tester,
        Scaffold(
          body: ReservationSteps(
            reservation: _res('r', ReservationStatus.pending),
          ),
        ),
      );
      expect(find.text('Qabul qilindi'), findsOneWidget);
      expect(find.text('Tayyorlanmoqda'), findsOneWidget);
      expect(find.text('Tayyor'), findsOneWidget);
      // Step 1 done (check), step 2 in progress, step 3 still numbered.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('a ready reservation completes all three steps', (
      tester,
    ) async {
      await _pump(
        tester,
        Scaffold(
          body: ReservationSteps(
            reservation: _res('r', ReservationStatus.ready),
          ),
        ),
      );
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    });

    testWidgets('home card shows the live bar, then the shortcut when idle', (
      tester,
    ) async {
      // Demo: one ready reservation.
      final c = await _pump(
        tester,
        Scaffold(
          body: ListView(
            children: [Builder(builder: pharmacyHomeCards.single.builder)],
          ),
        ),
      );
      expect(find.text('Olib ketishga tayyor: 1'), findsOneWidget);
      expect(find.byType(ReservationSteps), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));

      final ready = c.read(activeReservationsProvider).requireValue.single;
      await _whilePumping(
        tester,
        c.read(reservationsProvider.notifier).cancel(ready.id),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReservationSteps), findsNothing);
      expect(find.text('Dori qidirish va bron qilish'), findsOneWidget);
    });
  });

  group('ready celebration', () {
    testWidgets(
      'pending → ready: one full-screen banner, even with two hosts',
      (tester) async {
        final c = await _pump(
          tester,
          const Scaffold(
            body: Column(
              children: [
                ReadyCelebrationHost(child: SizedBox(height: 10)),
                ReadyCelebrationHost(child: SizedBox(height: 10)),
              ],
            ),
          ),
        );
        final sub = c.listen(medicineOffersProvider(_loratadine), (_, _) {});
        addTearDown(sub.close);
        final offers = await _whilePumping(
          tester,
          c.read(medicineOffersProvider(_loratadine).future),
        );
        await _whilePumping(
          tester,
          c
              .read(reservationsProvider.notifier)
              .reserve(offers.firstWhere((o) => o.inStock)),
        );
        await tester.pump();
        expect(find.byType(ReadyCelebration), findsNothing);

        // The fake pharmacy prepares it after 20 s.
        await tester.pump(const Duration(seconds: 21));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(ReadyCelebration), findsOneWidget);
        expect(find.text('Bron tayyor! 🎉'), findsOneWidget);
        expect(find.textContaining('olib ketishga tayyor!'), findsOneWidget);
        expect(c.read(readyCelebrationsProvider), isEmpty);

        // Confetti never settles under the test clock — close first.
        await tester.tap(find.text('Ajoyib!'));
        await tester.pumpAndSettle();
        expect(find.byType(ReadyCelebration), findsNothing);
      },
    );

    testWidgets('celebration renders in dark theme on a small phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prefs = await fakePrefs(signedIn: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(prefs: prefs, useFake: true),
          child: MaterialApp(
            theme: AppTheme.dark,
            locale: AppLang.uz.locale,
            supportedLocales: AppLang.locales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const ReadyCelebration(
              reservation: Reservation(
                id: 'r',
                medicineId: _loratadine,
                pharmacyId: 'p',
                status: ReservationStatus.ready,
                pharmacy: Pharmacy(
                  id: 'p',
                  name: 'Davo plyus dorixonasi — Chilonzor filiali',
                  address: 'Bunyodkor shoh ko‘chasi, 12-uy',
                  lat: 41.3,
                  lng: 69.2,
                ),
              ),
            ),
          ),
        ),
      );
      // Confetti never settles under the test clock: fixed pumps only.
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Yo‘nalish'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Rx badge', () {
    test('white text on the badge fill has contrast ≥ 4.5', () {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final base in [AppColors.coral, AppColors.good]) {
        final fill = AppColors.readable(base, Brightness.light);
        expect(contrast(fill, Colors.white), greaterThanOrEqualTo(4.5));
      }
    });

    testWidgets('big and compact badges for both kinds', (tester) async {
      await _pump(
        tester,
        const Scaffold(
          body: Column(
            children: [
              RxBadge(rx: true),
              RxBadge(rx: false),
              RxBadge(rx: true, compact: true),
            ],
          ),
        ),
      );
      expect(find.text('Retsept kerak'), findsNWidgets(2));
      expect(find.text('Retseptsiz'), findsOneWidget);
      final big = tester.getSize(find.byType(RxBadge).first);
      final small = tester.getSize(find.byType(RxBadge).last);
      expect(big.height, greaterThan(small.height + 10));
    });
  });

  testWidgets('pharmacy tab: gradient header with search and stats', (
    tester,
  ) async {
    await _pump(tester, const PharmacyScreen());
    expect(find.byType(GradientHeader), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GradientHeader),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
    expect(find.byType(StatTile), findsNWidgets(2));
    expect(find.text('Dorilar'), findsOneWidget);
    expect(find.text('Tayyor: 1'), findsOneWidget);
  });
}
