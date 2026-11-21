import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/app/app.dart';
import 'package:sino/app/router.dart';
import 'package:sino/core/backend/backend.dart';
import 'package:sino/core/contracts/home_card.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/home/application/home_today.dart';
import 'package:sino/features/home/application/sino_index.dart';
import 'package:sino/features/home/data/sino_data.dart';
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

/// Saturday evening — «Xayrli kech».
final _now = DateTime(2026, 11, 21, 20);

/// Counts loads so tests can see reloads.
class _CountingRepo implements SinoDataRepository {
  _CountingRepo({this.empty = false});
  final bool empty;
  int loads = 0;

  @override
  Future<SinoRaw> load({required DateTime from, required DateTime to}) {
    loads++;
    return empty
        ? Future.value(const SinoRaw())
        : FakeSinoDataRepository(clock: () => _now).load(from: from, to: to);
  }
}

List<Override> _sino(_CountingRepo repo) => [
  sinoClockProvider.overrideWithValue(() => _now),
  sinoDataRepositoryProvider.overrideWithValue(repo),
];

Future<void> _pumpHome(
  WidgetTester tester, {
  _CountingRepo? repo,
  AppLang lang = AppLang.uz,
  List<HomeCardSpec>? cards,
}) async {
  final prefs = await fakePrefs(signedIn: true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appOverrides(prefs: prefs, useFake: true),
        ..._sino(repo ?? _CountingRepo()),
        appLangProvider.overrideWith(() => _FixedLang(lang)),
        if (cards != null) homeCardsProvider.overrideWithValue(cards),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: lang.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('home exposes its root route', () {
    final paths = [for (final r in homeRoutes.whereType<GoRoute>()) r.path];
    expect(paths, contains(AppRoutes.home));
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

  group('Bugun', () {
    test('greeting by the time of day', () {
      expect(DayPart.of(DateTime(2026, 1, 1, 6)), DayPart.morning);
      expect(DayPart.of(DateTime(2026, 1, 1, 10, 59)), DayPart.morning);
      expect(DayPart.of(DateTime(2026, 1, 1, 11)), DayPart.day);
      expect(DayPart.of(DateTime(2026, 1, 1, 17)), DayPart.evening);
      expect(DayPart.of(DateTime(2026, 1, 1, 2)), DayPart.evening);
      expect(
        greeting(AppLang.uz, DayPart.morning, 'Aziz'),
        'Xayrli tong, Aziz',
      );
      expect(greeting(AppLang.uz, DayPart.day, 'Aziz'), 'Xayrli kun, Aziz');
      expect(greeting(AppLang.uz, DayPart.evening, ''), 'Xayrli kech');
      expect(
        greeting(AppLang.ru, DayPart.morning, 'Aziz'),
        'Доброе утро, Aziz',
      );
      expect(
        greeting(AppLang.en, DayPart.evening, 'Aziz'),
        'Good evening, Aziz',
      );
    });

    SinoDay day(SinoDayInput i) => SinoDay(input: i, index: null);
    final d = DateTime(2026, 11, 21);
    SinoDose dose(int h, bool taken) => SinoDose(
      at: d.add(Duration(hours: h)),
      taken: taken,
    );

    test('live summary line', () {
      final full = day(
        SinoDayInput(
          date: d,
          kcal: 1240,
          glasses: 5,
          doses: [dose(8, true), dose(13, true), dose(21, false)],
          steps: 6400,
        ),
      );
      expect(
        todaySummary(AppLang.uz, full, _now),
        'Bugun 1 240 kkal, 5 stakan suv, dorilar vaqtida\u00A0✓, 6 400 qadam',
      );
      expect(
        todaySummary(AppLang.ru, full, _now),
        'Сегодня 1 240 ккал, 5 стаканов воды, лекарства вовремя\u00A0✓, 6 400 шагов',
      );
      final missed = day(
        SinoDayInput(date: d, glasses: 1, doses: [dose(8, false)], workouts: 1),
      );
      expect(
        todaySummary(AppLang.en, missed, _now),
        'Today 1 glass of water, 1 dose missed, workout\u00A0✓',
      );
      expect(
        todaySummary(AppLang.uz, day(SinoDayInput(date: d)), _now),
        isNull,
      );
    });

    test('streak: days with index ≥ 60, today may still be in progress', () {
      SinoDay s(int? score) => SinoDay(
        input: SinoDayInput(date: d),
        index: score == null
            ? null
            : SinoIndex(
                date: d,
                parts: [
                  SinoPartResult(
                    part: SinoPart.water,
                    score: score / 100,
                    value: 0,
                    target: 8,
                    share: 1,
                  ),
                ],
              ),
      );
      expect(sinoStreak([s(70), s(80), s(65)]), 3);
      expect(sinoStreak([s(70), s(80), s(40)]), 2); // today not there yet
      expect(sinoStreak([s(70), s(30), s(90), s(null)]), 1);
      expect(sinoStreak([s(50), s(40)]), 0);
      expect(sinoStreak(const []), 0);
    });

    test('levels', () {
      expect(SinoLevel.of(95), SinoLevel.great);
      expect(SinoLevel.of(60), SinoLevel.good);
      expect(SinoLevel.of(59), SinoLevel.fair);
      expect(SinoLevel.of(10), SinoLevel.low);
    });

    test('groupThousands', () {
      expect(groupThousands(1240), '1 240');
      expect(groupThousands(10200), '10 200');
      expect(groupThousands(950), '950');
      expect(groupThousands(1000000), '1 000 000');
    });

    testWidgets('20 proverbs with uz/ru/en, a new one each day', (
      tester,
    ) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final quotes = await c.read(quotesProvider.future);
      expect(quotes, hasLength(20));
      for (final q in quotes) {
        expect([q.uz, q.ru, q.en].every((t) => t.trim().isNotEmpty), isTrue);
      }
      expect(quotes.map((q) => q.uz).toSet(), hasLength(20));
      expect(quoteIndexFor(DateTime(2026, 1, 1), 20), 0);
      expect(quoteIndexFor(DateTime(2026, 1, 2), 20), 1);
      expect(quoteIndexFor(DateTime(2026, 1, 21), 20), 0);
      expect(quotes.first.translation(AppLang.uz), isNull);
      expect(quotes.first.translation(AppLang.ru), quotes.first.ru);
    });
  });

  testWidgets('home «Bugun»: greeting, summary, index, week, quote, cards', (
    tester,
  ) async {
    _tallView(tester);
    await _pumpHome(tester);
    expect(find.text('Xayrli kech, Aziz'), findsOneWidget);
    expect(
      find.text(
        'Bugun 1 240 kkal, 5 stakan suv, dorilar vaqtida\u00A0✓, 6 400 qadam',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sino-index-score')), findsOneWidget);
    expect(find.text('Sino indeksi'), findsOneWidget);
    expect(find.text('Shifokor maslahatini almashtirmaydi'), findsOneWidget);
    // Fake week: the weak day 4 days ago, then 4 good days in a row.
    expect(find.text('4 kun ketma-ket'), findsOneWidget);
    expect(find.text('Sh'), findsOneWidget); // Saturday = today
    expect(find.byKey(const ValueKey('quote-uz')), findsOneWidget);
    expect(find.text('Kun hikmati'), findsOneWidget);
    expect(find.text('Xizmatlar'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('service-${AppRoutes.vitals}')),
      findsOneWidget,
    );
    expect(find.text('Siz uchun'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ru: translated greeting and the proverb translation', (
    tester,
  ) async {
    _tallView(tester);
    await _pumpHome(tester, lang: AppLang.ru);
    expect(find.text('Добрый вечер, Aziz'), findsOneWidget);
    expect(find.textContaining('Сегодня 1 240 ккал'), findsOneWidget);
    expect(find.text('Мудрость дня'), findsOneWidget);
    expect(find.text('Серия: 4 дня'), findsOneWidget);
  });

  testWidgets('tap on the index opens the breakdown', (tester) async {
    _tallView(tester);
    await _pumpHome(tester);
    await tester.tap(find.text('Sino indeksi'));
    await tester.pumpAndSettle();
    expect(find.text('Indeks qanday hisoblanadi'), findsOneWidget);
    for (final p in SinoPart.values) {
      expect(find.byKey(ValueKey('points-${p.name}')), findsOneWidget);
    }
    expect(find.text('1 240 / 2 270 kkal'), findsOneWidget);
    expect(find.text('5 / 8 stakan'), findsOneWidget);
  });

  testWidgets('nothing logged today → empty index card, still works', (
    tester,
  ) async {
    _tallView(tester);
    await _pumpHome(tester, repo: _CountingRepo(empty: true));
    expect(find.byKey(const ValueKey('sino-index-empty')), findsOneWidget);
    expect(find.textContaining('hech narsa qayd etilmagan'), findsOneWidget);
    expect(find.text('Seriyani bugun boshlang'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coming back to the home tab reloads today', (tester) async {
    _tallView(tester);
    final repo = _CountingRepo();
    final prefs = await fakePrefs(signedIn: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appOverrides(prefs: prefs, useFake: true),
          ..._sino(repo),
        ],
        child: const SinoApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SinoApp)),
    );
    final loads = repo.loads;
    expect(loads, greaterThan(0));
    container.read(routerProvider).go(AppRoutes.nutrition);
    await tester.pumpAndSettle();
    container.read(routerProvider).go(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(repo.loads, loads + 1);
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

class _FixedLang extends AppLangNotifier {
  _FixedLang(this.lang);
  final AppLang lang;

  @override
  AppLang build() => lang;
}
