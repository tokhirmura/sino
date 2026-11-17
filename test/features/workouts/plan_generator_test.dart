import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sino/features/workouts/application/plan_generator.dart';
import 'package:sino/features/workouts/data/models.dart';

final _catalog = [
  for (final r in jsonDecode(
    File('assets/wellness/exercises.json').readAsStringSync(),
  ) as List)
    Exercise.fromJson(r as Map<String, dynamic>),
];
final _byId = {for (final e in _catalog) e.id: e};

List<PlanDay> _gen(
  WorkoutType type,
  WorkoutGoal goal,
  int days, {
  WorkoutLevel level = WorkoutLevel.intermediate,
}) => generatePlan(
  PlanParams(type: type, goal: goal, level: level, daysPerWeek: days),
  _catalog,
);

Set<String> _exerciseIds(List<PlanDay> plan) => {
  for (final d in plan)
    for (final i in d.items) i.exerciseId,
};

Iterable<PlanItem> _items(List<PlanDay> plan) => plan.expand((d) => d.items);

/// Share of exercises two plans have in common (0 = disjoint, 1 = same).
double _overlap(List<PlanDay> a, List<PlanDay> b) {
  final x = _exerciseIds(a), y = _exerciseIds(b);
  return x.intersection(y).length / x.union(y).length;
}

double _avg(Iterable<num> v) => v.fold(0.0, (s, x) => s + x) / v.length;

void main() {
  test('every combination gives a valid plan', () {
    for (final type in WorkoutType.values) {
      for (final goal in WorkoutGoal.values) {
        for (final level in WorkoutLevel.values) {
          for (var days = minPlanDays; days <= maxPlanDays; days++) {
            final plan = _gen(type, goal, days, level: level);
            final tag = '${type.name}/${goal.name}/${level.name}/$days';
            expect(plan, hasLength(days), reason: tag);
            expect([for (final d in plan) d.weekday], planWeekdays[days]);
            expect(
              [for (final d in plan) d.day],
              [for (var i = 1; i <= days; i++) i],
            );
            for (final d in plan) {
              expect(d.items, isNotEmpty, reason: tag);
              expect(d.minutes, greaterThan(0), reason: tag);
              expect(d.kcal, greaterThan(0), reason: tag);
              expect(
                d.minutes,
                lessThanOrEqualTo(maxDayMinutes(level)),
                reason: tag,
              );
              // At least one exercise of the chosen sport every day.
              expect(
                d.items.any((i) => _byId[i.exerciseId]!.type == type),
                isTrue,
                reason: tag,
              );
              for (final i in d.items) {
                expect(_byId, contains(i.exerciseId));
                expect(i.sets, inInclusiveRange(1, 6));
                expect((i.reps == null) != (i.seconds == null), isTrue);
              }
            }
          }
        }
      }
    }
  });

  test('deterministic', () {
    final a = _gen(WorkoutType.gym, WorkoutGoal.gain, 5);
    final b = _gen(WorkoutType.gym, WorkoutGoal.gain, 5);
    expect(
      jsonEncode([for (final d in a) d.toJson()]),
      jsonEncode([for (final d in b) d.toJson()]),
    );
  });

  group('plans differ noticeably', () {
    test('home vs gym: different exercises, each from its own place', () {
      for (final goal in [WorkoutGoal.lose, WorkoutGoal.gain]) {
        final home = _gen(WorkoutType.home, goal, 3);
        final gym = _gen(WorkoutType.gym, goal, 3);
        expect(_overlap(home, gym), 0);
        expect(
          _items(home).every((i) => _byId[i.exerciseId]!.type.name == 'home'),
          isTrue,
        );
        expect(
          _items(gym).every((i) => _byId[i.exerciseId]!.type.name == 'gym'),
          isTrue,
        );
      }
    });

    test('lose vs gain: circuit with cardio vs heavy sets with long rest', () {
      for (final type in [WorkoutType.home, WorkoutType.gym]) {
        final lose = _gen(type, WorkoutGoal.lose, 3);
        final gain = _gen(type, WorkoutGoal.gain, 3);
        final loseParams = PlanParams(type: type, goal: WorkoutGoal.lose);
        final gainParams = PlanParams(type: type, goal: WorkoutGoal.gain);

        // Weight loss burns clearly more per minute.
        double kcalPerMin(List<PlanDay> p) =>
            _avg(p.map((d) => d.kcal)) / _avg(p.map((d) => d.minutes));
        expect(kcalPerMin(lose), greaterThan(kcalPerMin(gain) * 1.5));

        // Mass: more sets, fewer reps, longer rest.
        expect(
          _avg(_items(gain).map((i) => i.sets)),
          greaterThan(_avg(_items(lose).map((i) => i.sets))),
        );
        final gainReps = _items(gain).where((i) => i.reps != null);
        final loseReps = _items(lose).where((i) => i.reps != null);
        expect(
          _avg(gainReps.map((i) => i.reps!)),
          lessThan(_avg(loseReps.map((i) => i.reps!)) * 0.7),
        );
        expect(gainParams.restSeconds, greaterThan(loseParams.restSeconds * 2));

        // Mass has no cardio; loss starts with it.
        expect(
          _items(gain).any((i) => _byId[i.exerciseId]!.muscle == 'cardio'),
          isFalse,
        );
        if (type == WorkoutType.home) {
          expect(_byId[lose.first.items.first.exerciseId]!.muscle, 'cardio');
        }
      }
    });

    test('2 vs 6 days: long full-body days vs a short split', () {
      for (final type in [WorkoutType.home, WorkoutType.gym]) {
        for (final goal in [WorkoutGoal.lose, WorkoutGoal.gain]) {
          final two = _gen(type, goal, 2);
          final six = _gen(type, goal, 6);
          final tag = '${type.name}/${goal.name}';
          expect([for (final d in two) d.weekday], [1, 4]);
          expect([for (final d in six) d.weekday], [1, 2, 3, 4, 5, 6]);
          // Days of the 2-day plan are clearly longer…
          expect(
            _avg(two.map((d) => d.minutes)),
            greaterThan(_avg(six.map((d) => d.minutes)) * 1.4),
            reason: tag,
          );
          // …with more exercises each…
          expect(
            _avg(two.map((d) => d.items.length)),
            greaterThan(_avg(six.map((d) => d.items.length))),
            reason: tag,
          );
          // …while the week of 6 days is bigger in total.
          int week(List<PlanDay> p) => p.fold(0, (s, d) => s + d.minutes);
          expect(week(six), greaterThan(week(two)), reason: tag);
          // A split: the 6 days are not all the same.
          expect(
            {for (final d in six) d.items.map((i) => i.exerciseId).join()},
            hasLength(greaterThan(2)),
            reason: tag,
          );
        }
      }
    });

    test('gym mass on 5–6 days is push / pull / legs', () {
      final plan = _gen(WorkoutType.gym, WorkoutGoal.gain, 6);
      Set<String?> muscles(PlanDay d) => {
        for (final i in d.items.take(2)) _byId[i.exerciseId]!.muscle,
      };
      expect(
        muscles(plan[0]).intersection({'chest', 'shoulders', 'arms'}),
        isNotEmpty,
      );
      expect(muscles(plan[1]), contains('back'));
      expect(muscles(plan[2]), contains('legs'));
    });
  });

  test('beginner run endurance stays short; advanced gets more', () {
    final beginner = _gen(
      WorkoutType.run,
      WorkoutGoal.endurance,
      4,
      level: WorkoutLevel.beginner,
    );
    final advanced = _gen(
      WorkoutType.run,
      WorkoutGoal.endurance,
      4,
      level: WorkoutLevel.advanced,
    );
    for (final d in beginner) {
      expect(d.minutes, lessThanOrEqualTo(32));
    }
    expect(
      _avg(advanced.map((d) => d.minutes)),
      greaterThan(_avg(beginner.map((d) => d.minutes)) * 1.5),
    );
  });

  test('flexibility is light; swim mass still swims', () {
    final flex = _gen(WorkoutType.kurash, WorkoutGoal.flexibility, 3);
    for (final i in _items(flex)) {
      expect(_byId[i.exerciseId]!.kcalPerMin, lessThanOrEqualTo(6));
    }
    final swim = _gen(WorkoutType.swim, WorkoutGoal.gain, 3);
    for (final d in swim) {
      expect(
        d.items.where((i) => _byId[i.exerciseId]!.type == WorkoutType.swim),
        isNotEmpty,
      );
      expect(
        d.items.where((i) => _byId[i.exerciseId]!.type == WorkoutType.home),
        isNotEmpty,
      );
    }
  });

  test('params round-trip through json', () {
    const p = PlanParams(
      type: WorkoutType.yoga,
      goal: WorkoutGoal.flexibility,
      level: WorkoutLevel.advanced,
      daysPerWeek: 5,
    );
    expect(PlanParams.fromJson(p.toJson()), p);
    expect(p.toJson()['rest_seconds'], 20);
    expect(PlanParams.fromJson({'days': 99}).daysPerWeek, maxPlanDays);
    expect(generatePlan(p, const []), isEmpty);
  });
}
