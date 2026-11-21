import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/data/user.dart';
import 'package:sino/features/home/application/sino_index.dart';
import 'package:sino/features/home/data/sino_data.dart';

import '../../helpers/test_app.dart';

final _day = DateTime(2026, 11, 18); // Wednesday
final _evening = DateTime(2026, 11, 18, 22); // whole day counts
final _nextDay = DateTime(2026, 11, 19, 9);

SinoIndex? _calc(SinoDayInput i, {DateTime? now, int goal = 2000}) =>
    computeSinoIndex(i, kcalGoal: goal, now: now ?? _evening);

SinoDose _dose(int hour, {bool taken = true}) => SinoDose(
  at: _day.add(Duration(hours: hour)),
  taken: taken,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('computeSinoIndex', () {
    test('perfect day → 100, weights add up to 1', () {
      final i = _calc(
        SinoDayInput(
          date: _day,
          kcal: 2000,
          glasses: 8,
          doses: [_dose(8), _dose(20)],
          steps: 9000,
          sleepHours: 8,
        ),
      )!;
      expect(i.score, 100);
      expect(i.parts, hasLength(5));
      expect(i.parts.fold<double>(0, (s, p) => s + p.share), closeTo(1, 1e-9));
      expect(i.missing, isEmpty);
    });

    test('no data at all → null (not zero)', () {
      expect(_calc(SinoDayInput(date: _day)), isNull);
    });

    test('missing parts are left out and weights redistributed', () {
      // Only water: 4 of 8 glasses over a whole day → 50, not 10.
      final i = _calc(SinoDayInput(date: _day, glasses: 4))!;
      expect(i.score, 50);
      expect(i.part(SinoPart.water)!.share, 1);
      expect(i.missing, hasLength(4));

      // Water (20) perfect + sleep (15) at zero → 20 / 35 = 57.
      final j = _calc(SinoDayInput(date: _day, glasses: 8, sleepHours: 3))!;
      expect(j.score, 57);
      expect(j.part(SinoPart.water)!.share, closeTo(20 / 35, 1e-9));
    });

    test('zero is data: 0 glasses counts as 0 points', () {
      final i = _calc(SinoDayInput(date: _day, glasses: 0, sleepHours: 8))!;
      expect(i.part(SinoPart.water)!.score, 0);
      expect(i.score, (15 / 35 * 100).round());
    });

    test('nutrition: under the goal is partial, big overeating loses', () {
      double n(double kcal) =>
          _calc(SinoDayInput(date: _day, kcal: kcal))!
              .part(SinoPart.nutrition)!
              .score;
      expect(n(1000), closeTo(0.5, 1e-9));
      expect(n(2000), 1);
      expect(n(2200), 1); // up to 110 % is fine
      expect(n(2600), closeTo(0.5, 1e-9)); // 130 %
      expect(n(3000), closeTo(0, 1e-9)); // 150 %
    });

    test('today is judged by the share of the day that has passed', () {
      final morning = DateTime(2026, 11, 18, 9); // (9 − 7) / 14 → 0.25 floor
      final noon = DateTime(2026, 11, 18, 14); // 0.5
      expect(dayProgress(_day, morning), 0.25);
      expect(dayProgress(_day, noon), 0.5);
      expect(dayProgress(_day, _nextDay), 1); // yesterday is complete

      final input = SinoDayInput(date: _day, glasses: 4, kcal: 1000);
      expect(_calc(input, now: noon)!.score, 100); // on track at noon
      expect(_calc(input, now: _nextDay)!.score, 50); // the same day, finished
    });

    test('medicines: only due or taken doses count', () {
      final noon = DateTime(2026, 11, 18, 12);
      final doses = [
        _dose(8),
        _dose(10, taken: false),
        _dose(20, taken: false),
      ];
      final m = _calc(
        SinoDayInput(date: _day, doses: doses),
        now: noon,
      )!.part(SinoPart.medicines)!;
      expect(m.value, 1);
      expect(m.target, 2); // 20:00 is not due yet
      expect(m.score, 0.5);

      // Nothing due yet and nothing taken → no data.
      expect(
        _calc(
          SinoDayInput(date: _day, doses: [_dose(20, taken: false)]),
          now: noon,
        ),
        isNull,
      );
      // Taken early counts.
      expect(
        _calc(
          SinoDayInput(date: _day, doses: [_dose(20)]),
          now: noon,
        )!.part(SinoPart.medicines)!.score,
        1,
      );
    });

    test('activity: a workout is full marks, else steps / 8000', () {
      double a(SinoDayInput i) => _calc(i)!.part(SinoPart.activity)!.score;
      expect(a(SinoDayInput(date: _day, steps: 4000)), 0.5);
      expect(a(SinoDayInput(date: _day, steps: 12000)), 1);
      expect(a(SinoDayInput(date: _day, steps: 1000, workouts: 1)), 1);
      expect(a(SinoDayInput(date: _day, workouts: 1)), 1);
    });

    test('sleep: 7–9 h best', () {
      expect(sleepScore(8), 1);
      expect(sleepScore(7), 1);
      expect(sleepScore(5.5), closeTo(0.5, 1e-9));
      expect(sleepScore(4), 0);
      expect(sleepScore(10.5), closeTo(0.5, 1e-9));
    });
  });

  group('sinoDayInput', () {
    test('collects the day from raw rows', () {
      final raw = SinoRaw(
        food: [
          FoodRow(_day, 600),
          FoodRow(_day, 400.5),
          FoodRow(_day.subtract(const Duration(days: 1)), 999),
        ],
        water: [WaterRow(_day, 6)],
        reminders: const [
          ReminderRow(id: 'a', minutes: 8 * 60), // every day
          ReminderRow(id: 'b', minutes: 21 * 60, days: [3]), // Wednesday
          ReminderRow(id: 'c', minutes: 9 * 60, days: [1]), // Monday only
          ReminderRow(id: 'd', minutes: 10 * 60, active: false), // paused
          ReminderRow(id: 'e', minutes: 11 * 60, memberId: 'mom'), // family
        ],
        doseLogs: [
          DoseLogRow('a', _day.add(const Duration(hours: 8, minutes: 5))),
          DoseLogRow(
            'b',
            _day.subtract(const Duration(hours: 2)),
          ), // day before
        ],
        sessions: [_day.add(const Duration(hours: 19))],
        vitals: [
          VitalRow('steps', 3000, _day.add(const Duration(hours: 12))),
          VitalRow('steps', 7500, _day.add(const Duration(hours: 21))),
          VitalRow('sleep', 6, _day.add(const Duration(hours: 7))),
          VitalRow('sleep', 7.5, _day.add(const Duration(hours: 8))),
          VitalRow('sleep', 9, _day.add(const Duration(days: 1, hours: 7))),
        ],
      );
      final i = sinoDayInput(raw, _day.add(const Duration(hours: 15)));
      expect(i.date, _day);
      expect(i.kcal, 1000.5);
      expect(i.glasses, 6);
      expect(i.doses.map((d) => d.at.hour), [8, 21]);
      expect(i.doses.map((d) => d.taken), [true, false]);
      expect(i.steps, 7500);
      expect(i.workouts, 1);
      expect(i.sleepHours, 7.5);
    });

    test('no doses before the reminder was created', () {
      final raw = SinoRaw(
        reminders: [ReminderRow(id: 'a', minutes: 8 * 60, since: _day)],
      );
      expect(sinoDayInput(raw, _day).doses, hasLength(1));
      expect(
        sinoDayInput(raw, _day.subtract(const Duration(days: 1))).doses,
        isEmpty,
      );
    });

    test('empty day → no data', () {
      final i = sinoDayInput(const SinoRaw(), _day);
      expect(i.kcal, isNull);
      expect(i.glasses, isNull);
      expect(i.steps, isNull);
      expect(i.sleepHours, isNull);
      expect(computeSinoIndex(i, kcalGoal: 2000, now: _evening), isNull);
    });
  });

  test('parseSinoRows maps PostgREST rows (UTC → local, embedded kcal)', () {
    final raw = parseSinoRows(
      food: [
        {
          'date': '2026-11-18',
          'servings': 1.5,
          'foods': {'kcal': 600},
        },
      ],
      water: [
        {'date': '2026-11-18', 'glasses': 5},
      ],
      reminders: [
        {
          'id': 'r1',
          'member_id': null,
          'time': '08:30:00',
          'days': [1, 3, 5],
          'active': true,
        },
      ],
      doseLogs: [
        {'reminder_id': 'r1', 'taken_at': '2026-11-18T03:40:00+00:00'},
      ],
      sessions: [
        {'finished_at': '2026-11-18T14:00:00Z'},
      ],
      vitals: [
        {'kind': 'steps', 'value': 8123, 'measured_at': '2026-11-18T16:00:00Z'},
      ],
    );
    expect(raw.food.single.kcal, 900);
    expect(raw.water.single.glasses, 5);
    expect(raw.reminders.single.minutes, 510);
    expect(raw.reminders.single.days, [1, 3, 5]);
    expect(raw.doseLogs.single.takenAt.isUtc, isFalse);
    expect(
      raw.doseLogs.single.takenAt,
      DateTime.utc(2026, 11, 18, 3, 40).toLocal(),
    );
    expect(raw.vitals.single.value, 8123);
    expect(raw.sessions, hasLength(1));
  });

  test('calorie goal from the profile, fallback 2000', () {
    const aziz = UserProfile(
      id: 'u',
      fullName: 'Aziz',
      birthYear: 1997,
      heightCm: 178,
      weightKg: 76,
    );
    expect(sinoKcalGoal(aziz, year: 2026), 2270);
    expect(sinoKcalGoal(null, year: 2026), 2000);
    expect(
      sinoKcalGoal(const UserProfile(id: 'u', fullName: 'X'), year: 2026),
      2000,
    );
  });

  group('fake week of Aziz', () {
    final json = jsonDecode(
      File('assets/core/sino_week.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    test('a plausible week: every day has an index, one weak day', () {
      final now = DateTime(2026, 11, 21, 20, 30);
      final today = dateOnly(now);
      final from = today.subtract(const Duration(days: 6));
      final raw = buildFakeSinoRaw(json, now: now, from: from, to: today);
      final scores = [
        for (var i = 0; i < 7; i++)
          computeSinoIndex(
            sinoDayInput(raw, from.add(Duration(days: i))),
            kcalGoal: 2270,
            now: now,
          )!.score,
      ];
      expect(scores.every((s) => s >= 0 && s <= 100), isTrue);
      expect(scores.where((s) => s < 60), hasLength(1)); // days_ago 4
      expect(scores[2], lessThan(60));
      expect(scores.last, greaterThanOrEqualTo(60));
      final todayInput = sinoDayInput(raw, today);
      expect(todayInput.kcal, 1240);
      expect(todayInput.glasses, 5);
    });

    test('today morning: doses after now are not taken yet', () {
      final now = DateTime(2026, 11, 21, 9);
      final raw = buildFakeSinoRaw(
        json,
        now: now,
        from: dateOnly(now),
        to: dateOnly(now),
      );
      final i = sinoDayInput(raw, now);
      expect(i.doses.where((d) => d.taken), hasLength(1)); // 08:00 only
      // Morning: a third of the evening values, not 1 240 kcal at 9 am.
      expect(i.kcal, (1240 * 0.3333).roundToDouble());
      expect(i.glasses, 2);
      final idx = computeSinoIndex(i, kcalGoal: 2270, now: now)!;
      expect(idx.part(SinoPart.medicines)!.target, 1);
    });
  });

  test('providers: week of 7 days, today last (fake mode)', () async {
    final prefs = await fakePrefs(signedIn: true);
    final now = DateTime(2026, 11, 21, 20);
    final c = ProviderContainer(
      overrides: [
        ...appOverrides(prefs: prefs, useFake: true),
        sinoClockProvider.overrideWithValue(() => now),
        sinoDataRepositoryProvider.overrideWithValue(
          FakeSinoDataRepository(clock: () => now),
        ),
      ],
    );
    addTearDown(c.dispose);
    final week = await c.read(sinoWeekProvider.future);
    expect(week, hasLength(7));
    expect(week.first.date, DateTime(2026, 11, 15));
    expect(week.last.date, DateTime(2026, 11, 21));
    expect(week.every((d) => d.index != null), isTrue);
    final today = await c.read(sinoTodayProvider.future);
    expect(today.input.kcal, 1240);
  });
}
