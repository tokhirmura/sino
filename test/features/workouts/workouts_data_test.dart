import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/features/workouts/application/workout_math.dart';
import 'package:sino/features/workouts/data/models.dart';
import 'package:sino/features/workouts/data/workouts_repository.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

const _pushUps = Exercise(
  id: 'e1',
  type: WorkoutType.home,
  name: {'uz': 'X'},
  reps: 15,
  kcalPerMin: 8,
);
const _plank = Exercise(
  id: 'e2',
  type: WorkoutType.home,
  name: {'uz': 'Y'},
  seconds: 45,
  kcalPerMin: 4,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exercises.json: 40 rows, valid types, reps xor seconds', () {
    final rows = [
      for (final r in jsonDecode(
        File('assets/wellness/exercises.json').readAsStringSync(),
      ) as List)
        r as Map<String, dynamic>,
    ];
    expect(rows, hasLength(40));
    expect({for (final r in rows) r['id']}, hasLength(40));
    final types = {for (final t in WorkoutType.values) t.name};
    for (final r in rows) {
      expect(r['id'], matches(_uuid));
      expect(types, contains(r['type']));
      expect((r['reps'] == null) != (r['seconds'] == null), isTrue);
      expect(r['kcal_per_min'] as num, greaterThan(0));
      for (final l in ['uz', 'ru', 'en']) {
        expect((r['name'] as Map)[l], isNotEmpty);
        expect((r['hint'] as Map)[l], isNotEmpty);
      }
    }
    // every kind of training has exercises for the generator
    expect({for (final r in rows) r['type']}, types);
  });

  test('WorkoutPlan toJson → fromJson keeps the week', () {
    final plan = WorkoutPlan(
      id: 'p1',
      params: const {'type': 'home', 'days': 3},
      days: const [
        PlanDay(
          day: 1,
          weekday: 1,
          minutes: 20,
          kcal: 150,
          items: [
            PlanItem(exerciseId: 'e1', sets: 3, reps: 12),
            PlanItem(exerciseId: 'e2', sets: 2, seconds: 30),
          ],
        ),
      ],
      createdAt: DateTime.utc(2026, 11, 14, 10),
    );
    final back = WorkoutPlan.fromJson(plan.toJson());
    expect(back.params['days'], 3);
    expect(back.days.single.items[1].seconds, 30);
    expect(back.days.single.weekday, 1);
    expect(back.createdAt!.toUtc(), DateTime.utc(2026, 11, 14, 10));
  });

  group('math', () {
    test('item seconds and kcal', () {
      // 3 × 15 reps × 3 s = 135 s → 8 kcal/min × 2.25 min = 18
      const reps = PlanItem(exerciseId: 'e1', sets: 3);
      expect(itemSeconds(reps, _pushUps), 135);
      expect(itemKcal(reps, _pushUps), 18);
      // plan overrides catalog: 2 × 60 s
      const timed = PlanItem(exerciseId: 'e2', sets: 2, seconds: 60);
      expect(itemSeconds(timed, _plank), 120);
      expect(itemKcal(timed, _plank), 8);
    });

    test('day estimate adds rest time but skips unknown ids', () {
      final est = dayEstimate(
        const [
          PlanItem(exerciseId: 'e1', sets: 3),
          PlanItem(exerciseId: 'e2', sets: 2, seconds: 60),
          PlanItem(exerciseId: 'missing', sets: 5),
        ],
        {'e1': _pushUps, 'e2': _plank},
        restSeconds: 30,
      );
      // 135 + 120 + 30 × 5 = 405 s ≈ 7 min;
      // work 18 + 8 + rest 150 s × 2 kcal/min = 5 → 31 kcal
      expect(est.minutes, 7);
      expect(est.kcal, 31);
    });

    test('streak counts back from today or yesterday', () {
      final now = DateTime(2026, 11, 14, 12);
      WorkoutSession s(int daysAgo) => WorkoutSession(
        id: '$daysAgo',
        finishedAt: DateTime(2026, 11, 14 - daysAgo, 19),
      );
      expect(streakDays([s(0), s(1), s(2), s(4)], now), 3);
      expect(streakDays([s(1), s(2)], now), 2);
      expect(streakDays([s(2), s(3)], now), 0);
      expect(streakDays([], now), 0);
    });
  });

  group('FakeWorkoutsRepository', () {
    late FakeWorkoutsRepository repo;
    final now = DateTime(2026, 11, 14, 12);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = FakeWorkoutsRepository(
        await SharedPreferences.getInstance(),
        now: now,
      );
    });

    test('catalog filters by type', () async {
      expect(await repo.exercises(), hasLength(40));
      final kurash = await repo.exercises(type: WorkoutType.kurash);
      expect(kurash, isNotEmpty);
      expect(kurash.every((e) => e.type == WorkoutType.kurash), isTrue);
    });

    test('demo sessions give a 2-day streak; new session extends it', () async {
      final sessions = await repo.sessions();
      expect(sessions, hasLength(3));
      expect(streakDays(sessions, now), 2);
      expect(await repo.sessions(since: DateTime(2026, 11, 12)), hasLength(2));

      await repo.addSession(planDay: 1, kcal: 200);
      expect(await repo.sessions(), hasLength(4));
    });

    test('plan is saved and the latest is returned', () async {
      expect(await repo.latestPlan(), isNull);
      await repo.savePlan(
        params: const {'type': 'run'},
        days: const [PlanDay(day: 1, items: [])],
      );
      final plan = await repo.latestPlan();
      expect(plan!.params['type'], 'run');
      expect(plan.days, hasLength(1));
    });
  });
}
