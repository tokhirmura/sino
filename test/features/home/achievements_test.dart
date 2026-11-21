import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/data/achievements.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/home/application/achievements_check.dart';
import 'package:sino/features/home/application/sino_index.dart';
import 'package:sino/features/home/data/sino_data.dart';
import 'package:sino/features/home/presentation/home_screen.dart';

import '../../helpers/test_app.dart';

/// Saturday evening, before 21:00.
final _now = DateTime(2026, 11, 21, 20);

class _Repo implements SinoDataRepository {
  _Repo();
  bool reserved = false;

  @override
  Future<SinoRaw> load({required DateTime from, required DateTime to}) =>
      FakeSinoDataRepository(clock: () => _now).load(from: from, to: to);

  @override
  Future<bool> hasReservation() async => reserved;
}

/// [n] past days (oldest first) ending yesterday + today, built by [make].
List<SinoDay> _days(
  int n,
  SinoDayInput Function(DateTime day, int i) make, {
  DateTime? now,
}) {
  final t = now ?? _now;
  final today = DateTime(t.year, t.month, t.day);
  return [
    for (var i = n; i >= 0; i--)
      () {
        final input = make(today.subtract(Duration(days: i)), i);
        return SinoDay(
          input: input,
          index: computeSinoIndex(input, kcalGoal: 2200, now: t),
        );
      }(),
  ];
}

SinoDose _dose(DateTime day, int hour, bool taken) => SinoDose(
  at: day.add(Duration(hours: hour)),
  taken: taken,
);

Set<Achievement> _earned(List<SinoDay> days, {DateTime? now, bool r = false}) =>
    earnedAchievements(days, now: now ?? _now, hasReservation: r);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('earnedAchievements', () {
    test('nothing logged → nothing earned', () {
      expect(_earned(_days(29, (d, _) => SinoDayInput(date: d))), isEmpty);
    });

    test(
      'fake week of Aziz: workout, 10 000 steps, index 90+, full day',
      () async {
        final raw = await FakeSinoDataRepository(clock: () => _now)
            .load(from: _now.subtract(const Duration(days: 29)), to: _now);
        final days = _days(29, (d, _) => sinoDayInput(raw, d));
        expect(_earned(days), {
          Achievement.firstWorkout,
          Achievement.steps10k,
          Achievement.index90,
          Achievement.fullDay,
        });
      },
    );

    test('water: 7 days in a row with 8 glasses, 6 are not enough', () {
      expect(
        _earned(_days(6, (d, _) => SinoDayInput(date: d, glasses: 8))),
        contains(Achievement.water7),
      );
      expect(
        _earned(
          _days(6, (d, i) => SinoDayInput(date: d, glasses: i == 3 ? 7 : 9)),
        ),
        isNot(contains(Achievement.water7)),
      );
    });

    test('medicines: 3 days with every dose taken; no doses do not count', () {
      List<SinoDay> week(bool Function(int i) allTaken) => _days(
        6,
        (d, i) => SinoDayInput(
          date: d,
          doses: [_dose(d, 8, true), _dose(d, 13, allTaken(i))],
        ),
      );
      expect(
        _earned(week((i) => i >= 4 && i <= 6)),
        contains(Achievement.meds3),
      );
      expect(
        _earned(week((i) => i.isEven)),
        isNot(contains(Achievement.meds3)),
      );
      expect(
        _earned(_days(6, (d, _) => SinoDayInput(date: d))),
        isNot(contains(Achievement.meds3)),
      );
    });

    test('index 90+ needs 3 logged parts', () {
      expect(
        _earned(_days(2, (d, _) => SinoDayInput(date: d, glasses: 8))),
        isNot(contains(Achievement.index90)),
      );
      expect(
        _earned(
          _days(
            2,
            (d, _) =>
                SinoDayInput(date: d, glasses: 8, kcal: 2000, steps: 9000),
          ),
        ),
        contains(Achievement.index90),
      );
    });

    test('index 90+ today counts only after 21:00', () {
      SinoDayInput perfectToday(DateTime d, int i) => i == 0
          ? SinoDayInput(date: d, glasses: 8, kcal: 2000, steps: 9000)
          : SinoDayInput(date: d, glasses: 2);
      expect(
        _earned(_days(3, perfectToday)),
        isNot(contains(Achievement.index90)),
      );
      final late = DateTime(2026, 11, 21, 21, 30);
      expect(
        _earned(_days(3, perfectToday, now: late), now: late),
        contains(Achievement.index90),
      );
    });

    test('streak: 7 days with index ≥ 60', () {
      expect(
        _earned(_days(6, (d, _) => SinoDayInput(date: d, glasses: 8))),
        contains(Achievement.streak7),
      );
      expect(
        _earned(
          _days(6, (d, i) => SinoDayInput(date: d, glasses: i == 2 ? 2 : 8)),
        ),
        isNot(contains(Achievement.streak7)),
      );
    });

    test('10 000 steps, first workout, full day, reservation', () {
      final all = _earned(
        _days(
          1,
          (d, i) => SinoDayInput(
            date: d,
            steps: 10000,
            workouts: i == 1 ? 1 : 0,
            kcal: 2000,
            glasses: 8,
            sleepHours: 8,
            doses: [_dose(d, 8, true)],
          ),
        ),
        r: true,
      );
      expect(
        all,
        containsAll([
          Achievement.steps10k,
          Achievement.firstWorkout,
          Achievement.fullDay,
          Achievement.firstReservation,
        ]),
      );
      expect(
        _earned(_days(1, (d, _) => SinoDayInput(date: d, steps: 9999))),
        isEmpty,
      );
    });
  });

  group('achievements repository (fake)', () {
    late ProviderContainer c;
    setUp(() async {
      final prefs = await fakePrefs(signedIn: true);
      c = ProviderContainer(
        overrides: [
          ...appOverrides(prefs: prefs, useFake: true),
          sinoClockProvider.overrideWithValue(() => _now),
          sinoDataRepositoryProvider.overrideWithValue(_Repo()),
        ],
      );
      addTearDown(c.dispose);
    });

    test('unlock keeps the first date; unknown codes are skipped', () async {
      final repo = c.read(achievementsRepositoryProvider);
      await repo.unlock([Achievement.water7], DateTime(2026, 11, 1));
      await repo.unlock([
        Achievement.water7,
        Achievement.meds3,
      ], DateTime(2026, 11, 5));
      final got = await repo.unlocked();
      expect(got[Achievement.water7], DateTime(2026, 11, 1));
      expect(got[Achievement.meds3], DateTime(2026, 11, 5));

      expect(
        parseAchievementRows([
          {'code': 'nope', 'unlocked_at': '2026-11-01T00:00:00Z'},
          {'code': 'full_day', 'unlocked_at': '2026-11-01T00:00:00Z'},
        ]).keys,
        [Achievement.fullDay],
      );
    });

    test('new badges are saved once', () async {
      final fresh = await c.read(newAchievementsProvider.future);
      expect(fresh, [
        Achievement.firstWorkout,
        Achievement.steps10k,
        Achievement.index90,
        Achievement.fullDay,
      ]);
      expect((await c.read(achievementsProvider.future)).length, 4);
      expect(
        c.read(sharedPreferencesProvider).getString(PrefKeys.fakeAchievements),
        contains('first_workout'),
      );

      c.invalidate(sinoHistoryProvider);
      expect(await c.read(newAchievementsProvider.future), isEmpty);
    });
  });

  group('codes and texts', () {
    test('8 unique codes, uz/ru/en texts', () {
      expect(Achievement.values, hasLength(8));
      expect(Achievement.values.map((a) => a.code).toSet(), hasLength(8));
      for (final a in Achievement.values) {
        expect(Achievement.byCode(a.code), a);
        for (final l in AppLang.values) {
          expect(a.title(l), isNotEmpty);
          expect(a.hint(l), isNotEmpty);
        }
      }
    });
  });

  testWidgets('home celebrates new badges once, with confetti', (tester) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await fakePrefs(signedIn: true);
    final repo = _Repo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appOverrides(prefs: prefs, useFake: true),
          sinoClockProvider.overrideWithValue(() => _now),
          sinoDataRepositoryProvider.overrideWithValue(repo),
          achievementCelebrationProvider.overrideWithValue(true),
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
    // Confetti runs on the wall clock — pump frames instead of settling.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.byKey(const ValueKey('achievement-celebration')),
      findsOneWidget,
    );
    expect(find.text('4 ta yangi yutuq! 🎉'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-badge-index_90')), findsOneWidget);

    await tester.tap(find.text('Zo‘r!'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('achievement-celebration')), findsNothing);

    // A new reservation → only that badge is celebrated.
    repo.reserved = true;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    container.invalidate(sinoHistoryProvider);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Yangi yutuq! 🎉'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('new-badge-first_reservation')),
      findsOneWidget,
    );
    await tester.tap(find.text('Zo‘r!'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Nothing new → no dialog.
    container.invalidate(sinoHistoryProvider);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('achievement-celebration')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('celebration is off under flutter test by default', (
    tester,
  ) async {
    final prefs = await fakePrefs(signedIn: true);
    final c = ProviderContainer(
      overrides: appOverrides(prefs: prefs, useFake: true),
    );
    addTearDown(c.dispose);
    expect(c.read(achievementCelebrationProvider), isFalse);
  });
}
