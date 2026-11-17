import 'package:flutter_test/flutter_test.dart';
import 'package:sino/features/workouts/application/workout_math.dart';
import 'package:sino/features/workouts/data/models.dart';

PlanDay _d(int day, int? weekday) =>
    PlanDay(day: day, weekday: weekday, items: const []);

WorkoutSession _s(DateTime at) =>
    WorkoutSession(id: '${at.millisecondsSinceEpoch}', finishedAt: at);

void main() {
  // 2026-11-18 is a Wednesday (weekday 3).
  final wed = DateTime(2026, 11, 18, 9);
  final plan = [_d(1, 1), _d(2, 3), _d(3, 5)]; // Mon, Wed, Fri

  test('today when today is a training day and nothing is done yet', () {
    final n = nextWorkout(plan, wed, const [])!;
    expect(n.day.day, 2);
    expect(n.date, DateTime(2026, 11, 18));
  });

  test('a session today moves it to the next training day', () {
    final n = nextWorkout(plan, wed, [_s(DateTime(2026, 11, 18, 7))])!;
    expect(n.day.day, 3);
    expect(n.date, DateTime(2026, 11, 20)); // Friday
  });

  test('yesterday’s session does not count for today', () {
    final n = nextWorkout(plan, wed, [_s(DateTime(2026, 11, 17, 20))])!;
    expect(n.date, DateTime(2026, 11, 18));
  });

  test('wraps into next week', () {
    final sat = DateTime(2026, 11, 21, 12);
    final n = nextWorkout(plan, sat, const [])!;
    expect(n.day.day, 1);
    expect(n.date, DateTime(2026, 11, 23)); // Monday
    // Only Wednesday in the plan and it's done today → next Wednesday.
    final n2 = nextWorkout([_d(1, 3)], wed, [_s(wed)])!;
    expect(n2.date, DateTime(2026, 11, 25));
  });

  test('crosses a month end', () {
    final n = nextWorkout([_d(1, 2)], DateTime(2026, 11, 30, 10), const [])!;
    expect(n.date, DateTime(2026, 12, 1)); // Tuesday
  });

  test('days without weekday: first one, today or tomorrow', () {
    final days = [_d(1, null), _d(2, null)];
    expect(nextWorkout(days, wed, const [])!.date, DateTime(2026, 11, 18));
    expect(nextWorkout(days, wed, [_s(wed)])!.date, DateTime(2026, 11, 19));
  });

  test('empty plan → null', () {
    expect(nextWorkout(const [], wed, const []), isNull);
  });
}
