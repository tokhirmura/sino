import '../data/models.dart';
import 'workout_math.dart';

/// Phase of a running workout.
enum RunPhase {
  /// «Get ready» countdown before the first exercise.
  ready,

  /// A set of an exercise.
  work,

  /// Rest between sets / exercises.
  rest,

  /// Finished (all steps done or stopped early).
  done,
}

/// One step of the workout: a set of [item] (`work`) or a rest after it.
class RunStep {
  const RunStep.work(this.item, this.exercise, this.set)
    : rest = false,
      seconds = null;

  const RunStep.rest(this.item, this.exercise, this.set, int this.seconds)
    : rest = true;

  final PlanItem item;
  final Exercise exercise;

  /// 1-based set number of [item].
  final int set;
  final bool rest;

  /// Rest length; for work see [workSeconds] / [reps].
  final int? seconds;

  /// Countdown length of a timed set; `null` for a set of reps.
  int? get workSeconds => rest ? null : item.seconds ?? exercise.seconds;

  /// Reps of a set of reps; `null` for a timed set.
  int? get reps =>
      rest || workSeconds != null ? null : item.reps ?? exercise.reps ?? 10;
}

/// Seconds of the «get ready» countdown.
const readySeconds = 5;

/// How much «+15 s» adds to a rest.
const restExtraSeconds = 15;

/// Flattens a plan day into sets and rests: a rest after every set except
/// the last one of the day. Unknown exercises are skipped.
List<RunStep> buildSteps(
  PlanDay day,
  Map<String, Exercise> catalog, {
  required int restSeconds,
}) {
  final steps = <RunStep>[];
  final items = [
    for (final i in day.items)
      if (catalog[i.exerciseId] != null) i,
  ];
  for (var n = 0; n < items.length; n++) {
    final item = items[n];
    final e = catalog[item.exerciseId]!;
    final sets = item.sets < 1 ? 1 : item.sets;
    for (var s = 1; s <= sets; s++) {
      steps.add(RunStep.work(item, e, s));
      final last = n == items.length - 1 && s == sets;
      if (!last && restSeconds > 0) {
        steps.add(RunStep.rest(item, e, s, restSeconds));
      }
    }
  }
  return steps;
}

/// Immutable state of a running workout. Every action returns a new state;
/// the screen only calls [tick] once a second and the buttons.
class WorkoutRun {
  const WorkoutRun._({
    required this.steps,
    required this.phase,
    required this.index,
    required this.remaining,
    required this.paused,
    required this.elapsed,
    required this.workKcal,
    required this.restSeconds,
    required this.setsDone,
  });

  /// Starts with the «get ready» countdown (or done if [steps] is empty).
  factory WorkoutRun.start(List<RunStep> steps) => WorkoutRun._(
    steps: steps,
    phase: steps.isEmpty ? RunPhase.done : RunPhase.ready,
    index: 0,
    remaining: steps.isEmpty ? 0 : readySeconds,
    paused: false,
    elapsed: 0,
    workKcal: 0,
    restSeconds: 0,
    setsDone: 0,
  );

  final List<RunStep> steps;
  final RunPhase phase;

  /// Current step (in `ready` — the first one, in `done` — `steps.length`).
  final int index;

  /// Seconds left of the current countdown; for a set of reps — seconds
  /// spent on it so far (counts up).
  final int remaining;
  final bool paused;

  /// Seconds of the whole workout (not counting pauses).
  final int elapsed;

  /// Calories of the work actually done.
  final double workKcal;

  /// Seconds actually rested.
  final int restSeconds;
  final int setsDone;

  RunStep? get step => index < steps.length ? steps[index] : null;

  /// The next work step after the current one (for «next up»).
  RunStep? get nextWork {
    for (var i = index + 1; i < steps.length; i++) {
      if (!steps[i].rest) return steps[i];
    }
    return null;
  }

  int get totalSets => steps.where((s) => !s.rest).length;

  /// Progress 0…1 by steps passed.
  double get progress => steps.isEmpty
      ? 1
      : phase == RunPhase.done
      ? 1
      : index / steps.length;

  /// Calories so far: work done + rest.
  double get kcal => workKcal + restKcalPerMin * restSeconds / 60;

  /// Minutes, rounded up from 30 s.
  int get minutes => (elapsed / 60).round();

  /// XP: 1 per kcal + 5 per set + 20 for finishing every set.
  int get xp =>
      kcal.round() +
      5 * setsDone +
      (setsDone == totalSets && totalSets > 0 ? 20 : 0);

  bool get isTimedWork => phase == RunPhase.work && step?.workSeconds != null;

  WorkoutRun _copy({
    RunPhase? phase,
    int? index,
    int? remaining,
    bool? paused,
    int? elapsed,
    double? workKcal,
    int? restSeconds,
    int? setsDone,
  }) => WorkoutRun._(
    steps: steps,
    phase: phase ?? this.phase,
    index: index ?? this.index,
    remaining: remaining ?? this.remaining,
    paused: paused ?? this.paused,
    elapsed: elapsed ?? this.elapsed,
    workKcal: workKcal ?? this.workKcal,
    restSeconds: restSeconds ?? this.restSeconds,
    setsDone: setsDone ?? this.setsDone,
  );

  /// Enters step [i] (work or rest), or finishes after the last one.
  WorkoutRun _enter(int i, {double addKcal = 0, int addSets = 0}) {
    final kcal = workKcal + addKcal;
    final sets = setsDone + addSets;
    if (i >= steps.length) {
      return _copy(
        phase: RunPhase.done,
        index: steps.length,
        remaining: 0,
        paused: false,
        workKcal: kcal,
        setsDone: sets,
      );
    }
    final s = steps[i];
    return _copy(
      phase: s.rest ? RunPhase.rest : RunPhase.work,
      index: i,
      remaining: s.rest ? s.seconds! : (s.workSeconds ?? 0),
      paused: false,
      workKcal: kcal,
      setsDone: sets,
    );
  }

  /// Calories of [seconds] of work of the current step.
  double _kcalOf(int seconds) =>
      (step?.exercise.kcalPerMin ?? 0) * seconds / 60;

  /// One second passed.
  WorkoutRun tick() {
    if (paused || phase == RunPhase.done) return this;
    final t = elapsed + 1;
    switch (phase) {
      case RunPhase.ready:
        return remaining > 1
            ? _copy(remaining: remaining - 1, elapsed: t)
            : _copy(elapsed: t)._enter(0);
      case RunPhase.rest:
        final rested = _copy(elapsed: t, restSeconds: restSeconds + 1);
        return remaining > 1
            ? rested._copy(remaining: remaining - 1)
            : rested._enter(index + 1);
      case RunPhase.work:
        if (!isTimedWork) {
          // A set of reps: count time up until «Done».
          return _copy(remaining: remaining + 1, elapsed: t);
        }
        if (remaining > 1) return _copy(remaining: remaining - 1, elapsed: t);
        return _copy(
          elapsed: t,
        )._enter(index + 1, addKcal: _kcalOf(step!.workSeconds!), addSets: 1);
      case RunPhase.done:
        return this;
    }
  }

  /// «Done» on a set of reps — or finishing a timed set early (counts
  /// the seconds actually worked).
  WorkoutRun completeSet() {
    if (phase != RunPhase.work) return this;
    final s = step!;
    final worked = s.workSeconds != null
        ? s.workSeconds! - remaining
        : (s.reps! * secondsPerRep);
    return _enter(index + 1, addKcal: _kcalOf(worked), addSets: 1);
  }

  /// Skips the «get ready» countdown or the rest.
  WorkoutRun skip() => switch (phase) {
    RunPhase.ready => _enter(0),
    RunPhase.rest => _enter(index + 1),
    _ => this,
  };

  /// Skips the current set without counting it.
  WorkoutRun skipSet() => phase == RunPhase.work ? _enter(index + 1) : this;

  /// «+15 s» to the rest.
  WorkoutRun addRest() => phase == RunPhase.rest
      ? _copy(remaining: remaining + restExtraSeconds)
      : this;

  WorkoutRun togglePause() =>
      phase == RunPhase.done ? this : _copy(paused: !paused);

  /// Stops early: done with what has been done so far.
  WorkoutRun finish() => phase == RunPhase.done ? this : _enter(steps.length);
}
