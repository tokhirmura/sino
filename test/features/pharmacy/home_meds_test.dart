import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/theme/app_colors.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/core/widgets/widgets.dart';
import 'package:sino/features/pharmacy/application/home_meds_providers.dart';
import 'package:sino/features/pharmacy/data/home_meds_repository.dart';
import 'package:sino/features/pharmacy/presentation/home_meds_screen.dart';
import 'package:sino/features/pharmacy/presentation/pharmacy_screen.dart';

import '../../helpers/test_app.dart';

/// Fixed "today" — demo expiry dates and badges are relative to it.
final _now = DateTime(2026, 11, 21, 10);

HomeMed _med(int? days, {int qty = 1}) => HomeMed(
  id: 'x',
  name: 'X',
  quantity: qty,
  expiryDate: days == null
      ? null
      : DateTime(_now.year, _now.month, _now.day + days),
);

/// The cabinet under a real GoRouter: `/pharmacy` shows the received
/// query, `/pharmacy/home-meds` — the screen.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  AppLang lang = AppLang.uz,
  bool dark = false,
  String? scannedCode,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'core.fake_signed_in': true,
    ...prefs,
  });
  final sp = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '${AppRoutes.pharmacy}/home-meds',
    routes: [
      GoRoute(
        path: AppRoutes.pharmacy,
        builder: (_, s) =>
            Scaffold(body: Text('search:${s.uri.queryParameters['q']}')),
        routes: [
          GoRoute(path: 'home-meds', builder: (_, _) => const HomeMedsScreen()),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appOverrides(prefs: sp, useFake: true),
        homeMedsClockProvider.overrideWithValue(() => _now),
        homeMedsScannerProvider.overrideWithValue((_) async => scannedCode),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: dark ? AppTheme.dark : AppTheme.light,
        locale: lang.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(HomeMedsScreen)));
}

void main() {
  group('expiry logic', () {
    test('expired / soon (≤ 30 days) / ok / unknown', () {
      expect(expiryState(_med(-1), _now), ExpiryState.expired);
      expect(expiryState(_med(0), _now), ExpiryState.soon);
      expect(expiryState(_med(30), _now), ExpiryState.soon);
      expect(expiryState(_med(31), _now), ExpiryState.ok);
      expect(expiryState(_med(null), _now), ExpiryState.unknown);
      expect(daysUntilExpiry(_med(18), _now), 18);
    });

    test('day count ignores DST and time of day', () {
      final late = DateTime(2027, 3, 27, 23, 59);
      final m = HomeMed(id: 'x', name: 'X', expiryDate: DateTime(2027, 4, 2));
      expect(daysUntilExpiry(m, late), 6);
    });

    test('sorting: by expiry, no date last, then name', () {
      final list = sortHomeMeds([
        HomeMed(id: '1', name: 'b'),
        HomeMed(id: '2', name: 'a', expiryDate: DateTime(2027)),
        HomeMed(id: '3', name: 'c', expiryDate: DateTime(2026)),
        HomeMed(id: '4', name: 'a'),
      ]);
      expect(list.map((m) => m.id), ['3', '2', '4', '1']);
    });

    test('row round-trip keeps date only and drops empty notes', () {
      final m = HomeMed(
        id: 'i',
        name: '  Paracetamol ',
        medicineId: 'mid',
        expiryDate: DateTime(2027, 3, 5),
        quantity: 2,
        notes: '  ',
      );
      final row = m.toRow();
      expect(row['expiry_date'], '2027-03-05');
      expect(row['name'], 'Paracetamol');
      expect(row['notes'], isNull);
      final back = HomeMed.fromJson({...row, 'id': 'i'});
      expect(back.expiryDate, DateTime(2027, 3, 5));
      expect(back.quantity, 2);
    });
  });

  group('FakeHomeMedsRepository', () {
    test(
      'seeds the demo once, relative to today; add / update / remove',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        TestWidgetsFlutterBinding.ensureInitialized();
        final repo = FakeHomeMedsRepository(prefs, now: _now);
        final first = await Future.wait([repo.list(), repo.list()]);
        expect(first[0], hasLength(5));
        expect(first[1], hasLength(5));
        final para = first[0].firstWhere(
          (m) => m.name.startsWith('Paracetamol'),
        );
        expect(para.medicineId, 'a1000000-0000-4000-8000-000000000001');
        expect(daysUntilExpiry(para, _now), 140);

        final added = await repo.add(const HomeMed(id: '', name: 'Yangi'));
        expect(added.id, startsWith('fake-home-'));
        await repo.update(added.copyWith(quantity: 4));
        expect(
          (await repo.list()).firstWhere((m) => m.id == added.id).quantity,
          4,
        );
        await repo.remove(added.id);
        expect(await repo.list(), hasLength(5));
        // Re-created repo reads prefs, does not re-seed.
        expect(
          await FakeHomeMedsRepository(prefs, now: _now).list(),
          hasLength(5),
        );
      },
    );
  });

  group('HomeMedsScreen', () {
    testWidgets('list sorted by expiry with 30-day badges and summary', (
      tester,
    ) async {
      final c = await _pump(tester);
      expect(find.byType(StatTile), findsNWidgets(3));
      expect(c.read(homeMedsProvider).value, hasLength(5));
      expect(find.byType(HomeMedTile), findsWidgets);
      expect(find.byKey(const ValueKey('expiry-expired')), findsOneWidget);
      expect(find.byKey(const ValueKey('expiry-soon')), findsOneWidget);
      expect(find.text('18 kun qoldi'), findsOneWidget);
      expect(find.text('Muddati o‘tgan'), findsOneWidget);
      // Expired Smecta is first.
      final tiles = tester.widgetList<HomeMedTile>(find.byType(HomeMedTile));
      expect(tiles.first.med.name, startsWith('Smekta'));
      expect(
        find.text('Muddati o‘tgan dorini ichmang — dorixonaga topshiring.'),
        findsOneWidget,
      );
    });

    testWidgets('«Buyurtma berish» opens /pharmacy?q=<name>', (tester) async {
      await _pump(tester);
      final smecta = tester
          .widgetList<HomeMedTile>(find.byType(HomeMedTile))
          .first
          .med
          .name;
      await tester.tap(find.byKey(const ValueKey('home-med-order')).first);
      await tester.pumpAndSettle();
      expect(find.text('search:$smecta'), findsOneWidget);
    });

    testWidgets('«Qayta buyurtma» on a valid medicine', (tester) async {
      await _pump(tester);
      final reorder = find.byKey(const ValueKey('home-med-reorder'));
      expect(reorder, findsWidgets);
      await tester.ensureVisible(reorder.first);
      await tester.pumpAndSettle();
      final tile = tester.widget<HomeMedTile>(
        find.ancestor(of: reorder.first, matching: find.byType(HomeMedTile)),
      );
      await tester.tap(reorder.first);
      await tester.pumpAndSettle();
      expect(find.text('search:${tile.med.name}'), findsOneWidget);
    });

    testWidgets('add from the catalog with an expiry date', (tester) async {
      final c = await _pump(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('home-med-name')),
        'lorat',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey(
            'home-med-suggestion-a1000000-0000-4000-8000-000000000023',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Katalogdan tanlandi'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-med-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('home-med-save')));
      await tester.tap(find.byKey(const ValueKey('home-med-save')));
      await tester.pumpAndSettle();

      final list = c.read(homeMedsProvider).value!;
      final lor = list.firstWhere((m) => m.name == 'Loratadin 10 mg');
      expect(lor.medicineId, 'a1000000-0000-4000-8000-000000000023');
      expect(lor.expiryDate, isNotNull);
      expect(find.textContaining('Uy dorixonasiga saqlandi'), findsOneWidget);
    });

    testWidgets('add by barcode scan', (tester) async {
      final c = await _pump(tester, scannedCode: '4781000000011');
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Shtrix-kodni skanerlash'));
      await tester.pumpAndSettle();
      expect(find.text('Paracetamol 500 mg'), findsWidgets);
      expect(find.text('Katalogdan tanlandi'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('home-med-save')));
      await tester.tap(find.byKey(const ValueKey('home-med-save')));
      await tester.pumpAndSettle();
      expect(
        c
            .read(homeMedsProvider)
            .value!
            .where((m) => m.name == 'Paracetamol 500 mg'),
        hasLength(2),
      );
    });

    testWidgets('unknown barcode shows a message; empty name is rejected', (
      tester,
    ) async {
      await _pump(tester, scannedCode: '0000000000000');
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Shtrix-kodni skanerlash'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Shtrix-kod bo‘yicha dori topilmadi'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('home-med-save')));
      await tester.tap(find.byKey(const ValueKey('home-med-save')));
      await tester.pumpAndSettle();
      expect(find.text('Dori nomini kiriting'), findsOneWidget);
    });

    testWidgets('edit quantity, delete with undo', (tester) async {
      final c = await _pump(tester);
      final first = tester
          .widgetList<HomeMedTile>(find.byType(HomeMedTile))
          .first
          .med;
      await tester.tap(find.text(first.name));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ko‘proq'));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('home-med-save')));
      await tester.tap(find.byKey(const ValueKey('home-med-save')));
      await tester.pumpAndSettle();
      expect(
        c
            .read(homeMedsProvider)
            .value!
            .firstWhere((m) => m.id == first.id)
            .quantity,
        first.quantity + 1,
      );

      await tester.tap(find.text(first.name));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('O‘chirish'));
      await tester.tap(find.text('O‘chirish'));
      await tester.pumpAndSettle();
      expect(c.read(homeMedsProvider).value, hasLength(4));
      await tester.tap(find.text('Qaytarish'));
      await tester.pumpAndSettle();
      expect(c.read(homeMedsProvider).value, hasLength(5));
    });

    testWidgets('empty cabinet → EmptyState with an action', (tester) async {
      await _pump(tester, prefs: {FakeHomeMedsRepository.storeKey: '[]'});
      expect(find.byType(EmptyState), findsOneWidget);
      await tester.tap(find.text('Dori qo‘shish'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeMedSheet), findsOneWidget);
    });

    testWidgets('loading error → retry', (tester) async {
      await _pump(tester, prefs: {FakeHomeMedsRepository.storeKey: 'not json'});
      expect(find.byType(ErrorView), findsOneWidget);
    });

    testWidgets('expiry badges keep ≥ 4.5:1 contrast', (tester) async {
      for (final c in [AppColors.garnet, AppColors.saffron]) {
        final fill = AppColors.readable(c, Brightness.light);
        final l1 = Colors.white.computeLuminance();
        final l2 = fill.computeLuminance();
        expect((l1 + 0.05) / (l2 + 0.05), greaterThanOrEqualTo(4.5));
      }
    });

    for (final lang in AppLang.values) {
      for (final dark in [false, true]) {
        testWidgets(
          'renders without overflow: ${lang.name} ${dark ? 'dark' : 'light'}',
          (tester) async {
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(const SizedBox());
            await _pump(tester, lang: lang, dark: dark);
            await tester.binding.setSurfaceSize(null);
            expect(tester.takeException(), isNull);
            expect(find.byType(HomeMedTile), findsWidgets);
            await tester.tap(find.byType(FloatingActionButton));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(HomeMedSheet), findsOneWidget);
          },
        );
      }
    }
  });

  testWidgets('pharmacy tab shows the «Uy dorixonasi» entry with warnings', (
    tester,
  ) async {
    final sp = await fakePrefs(signedIn: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appOverrides(prefs: sp, useFake: true),
          homeMedsClockProvider.overrideWithValue(() => _now),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: AppLang.uz.locale,
          supportedLocales: AppLang.locales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const PharmacyScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('home-meds-entry'));
    await tester.scrollUntilVisible(
      entry,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(entry, findsOneWidget);
    expect(
      find.text('5 ta dori · 2 tasining muddati tugayapti'),
      findsOneWidget,
    );
  });
}
