import 'package:flutter_test/flutter_test.dart';
import 'package:sino/features/workouts/application/workout_math.dart';
import 'package:sino/features/workouts/application/workout_run.dart';
import 'package:sino/features/workouts/data/models.dart';

const _plank = Exercise(
  id: 'plank',
  type: WorkoutType.home,
  name: {'uz': 'Planka'},
  seconds: 45,
  kcalPerMin: 6,
);
const _push = Exercise(
  id: 'push',
  type: WorkoutType.home,
  name: {'uz': 'Push'},
  reps: 15,
  kcalPerMin: 8,
);
final _catalog = {_plank.id: _plank, _push.id: _push};

const _day = PlanDay(
  day: 1,
  items: [
    PlanItem(exerciseId: 'plank', sets: 2, seconds: 10),
    PlanItem(exerciseId: 'push', sets: 1, reps: 12),
    PlanItem(exerciseId: 'missing', sets: 3),
  ],
);

WorkoutRun _ticks(WorkoutRun r, int n) {
  for (var i = 0; i < n; i++) {
    r = r.tick();
  }
  return r;
}

void main() {
  final steps = buildSteps(_day, _catalog, restSeconds: 30);

  test(
    'steps: sets with rests between, none after the last; unknown skipped',
    () {
      expect(
        [for (final s in steps) s.rest ? 'rest' : s.exercise.id],
        ['plank', 'rest', 'plank', 'rest', 'push'],
      );
      expect(steps[0].workSeconds, 10);
      expect(steps[4].reps, 12);
      expect(steps[4].workSeconds, isNull);
      expect(buildSteps(_day, _catalog, restSeconds: 0), hasLength(3));
    },
  );

  test('ready countdown → timed set counts down → rest → next set', () {
    var r = WorkoutRun.start(steps);
    expect(r.phase, RunPhase.ready);
    expect(r.remaining, readySeconds);
    r = _ticks(r, readySeconds);
    expect(r.phase, RunPhase.work);
    expect(r.remaining, 10);
    r = _ticks(r, 3);
    expect(r.remaining, 7);
    r = _ticks(r, 7);
    expect(r.phase, RunPhase.rest);
    expect(r.remaining, 30);
    expect(r.setsDone, 1);
    expect(r.workKcal, closeTo(6 * 10 / 60, 1e-9));
    r = _ticks(r, 30);
    expect(r.phase, RunPhase.work);
    expect(r.step!.set, 2);
    expect(r.elapsed, readySeconds + 10 + 30);
    expect(r.restSeconds, 30);
  });

  test('skip rest, +15 s, pause', () {
    var r = WorkoutRun.start(steps).skip(); // skip «get ready»
    expect(r.phase, RunPhase.work);
    r = _ticks(r, 10);
    expect(r.phase, RunPhase.rest);
    r = r.addRest();
    expect(r.remaining, 30 + restExtraSeconds);
    r = _ticks(r, 5);
    r = r.skip();
    expect(r.phase, RunPhase.work);
    expect(r.restSeconds, 5); // only the seconds actually rested
    r = r.togglePause();
    expect(_ticks(r, 20).remaining, 10);
    expect(_ticks(r, 20).elapsed, r.elapsed);
  });

  test('reps: time counts up, «Done» counts reps × 3 s of work', () {
    var r = WorkoutRun.start(steps).skip();
    r = r.skipSet(); // plank set 1 skipped — not counted
    expect(r.setsDone, 0);
    r = r.skip().completeSet(); // rest skipped, plank set 2 done at once
    expect(r.workKcal, 0); // 0 s worked
    r = r.skip();
    expect(r.step!.exercise.id, 'push');
    r = _ticks(r, 4);
    expect(r.remaining, 4);
    r = r.completeSet();
    expect(r.phase, RunPhase.done);
    expect(r.setsDone, 2);
    expect(r.totalSets, 3);
    expect(r.workKcal, closeTo(8 * 12 * secondsPerRep / 60, 1e-9));
    expect(r.progress, 1);
    expect(r.tick().elapsed, r.elapsed);
  });

  test('timed set finished early counts the seconds worked', () {
    var r = WorkoutRun.start(steps).skip();
    r = _ticks(r, 4).completeSet();
    expect(r.workKcal, closeTo(6 * 4 / 60, 1e-9));
  });

  test('kcal, minutes and XP of a full workout', () {
    var r = WorkoutRun.start(steps).skip();
    r = _ticks(r, 10 + 30 + 10 + 30);
    expect(r.step!.exercise.id, 'push');
    r = r.completeSet();
    expect(r.phase, RunPhase.done);
    // work: 6×20/60 + 8×36/60 = 2 + 4.8; rest: 2 × 60/60 = 2
    expect(r.kcal, closeTo(8.8, 1e-9));
    expect(r.minutes, 1); // 80 s
    expect(r.xp, 9 + 5 * 3 + 20);
  });

  test('finish early; empty day is done at once', () {
    final r = WorkoutRun.start(steps).skip().completeSet().finish();
    expect(r.phase, RunPhase.done);
    expect(r.setsDone, 1);
    expect(r.xp, 0 + 5); // no bonus — not all sets
    expect(WorkoutRun.start(const []).phase, RunPhase.done);
  });
}
