import '../data/models.dart';
import 'workout_math.dart';

/// Training goal of a generated plan.
enum WorkoutGoal {
  /// «Ozish» — burn calories: many exercises in a circuit, high reps,
  /// short rest, cardio first.
  lose,

  /// «Massa» — build muscle: strength moves, more sets, fewer heavier reps,
  /// long rest, no cardio.
  gain,

  /// «Chidamlilik» — long timed work, moderate rest.
  endurance,

  /// «Egiluvchanlik» — stretches and holds, light load.
  flexibility;

  static WorkoutGoal fromName(String? s) =>
      values.firstWhere((g) => g.name == s, orElse: () => WorkoutGoal.lose);
}

enum WorkoutLevel {
  beginner,
  intermediate,
  advanced;

  static WorkoutLevel fromName(String? s) => values.firstWhere(
    (l) => l.name == s,
    orElse: () => WorkoutLevel.beginner,
  );
}

/// Allowed training days per week.
const minPlanDays = 2;
const maxPlanDays = 6;

/// Generator inputs; stored as `workout_plans.params`.
class PlanParams {
  const PlanParams({
    this.type = WorkoutType.home,
    this.goal = WorkoutGoal.lose,
    this.level = WorkoutLevel.beginner,
    this.daysPerWeek = 3,
  });

  final WorkoutType type;
  final WorkoutGoal goal;
  final WorkoutLevel level;
  final int daysPerWeek;

  /// Rest between sets, seconds (by goal).
  int get restSeconds => switch (goal) {
    WorkoutGoal.lose => 30,
    WorkoutGoal.gain => 90,
    WorkoutGoal.endurance => 45,
    WorkoutGoal.flexibility => 20,
  };

  PlanParams copyWith({
    WorkoutType? type,
    WorkoutGoal? goal,
    WorkoutLevel? level,
    int? daysPerWeek,
  }) => PlanParams(
    type: type ?? this.type,
    goal: goal ?? this.goal,
    level: level ?? this.level,
    daysPerWeek: daysPerWeek ?? this.daysPerWeek,
  );

  factory PlanParams.fromJson(Map<String, dynamic> m) => PlanParams(
    type: WorkoutType.fromName(m['type'] as String?),
    goal: WorkoutGoal.fromName(m['goal'] as String?),
    level: WorkoutLevel.fromName(m['level'] as String?),
    daysPerWeek: ((m['days'] as num?)?.toInt() ?? 3).clamp(
      minPlanDays,
      maxPlanDays,
    ),
  );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'goal': goal.name,
    'level': level.name,
    'days': daysPerWeek,
    'rest_seconds': restSeconds,
  };

  @override
  bool operator ==(Object other) =>
      other is PlanParams &&
      other.type == type &&
      other.goal == goal &&
      other.level == level &&
      other.daysPerWeek == daysPerWeek;

  @override
  int get hashCode => Object.hash(type, goal, level, daysPerWeek);
}

/// Training weekdays (1 = Mon … 7 = Sun) with rest days spread out.
const planWeekdays = <int, List<int>>{
  2: [1, 4],
  3: [1, 3, 5],
  4: [1, 2, 4, 5],
  5: [1, 2, 3, 5, 6],
  6: [1, 2, 3, 4, 5, 6],
};

/// Focus of one training day — the muscle groups it prefers.
enum DayFocus {
  full({}),
  upper({'chest', 'back', 'shoulders', 'arms', 'core'}),
  lower({'legs', 'glutes', 'core'}),
  push({'chest', 'shoulders', 'arms'}),
  pull({'back', 'arms', 'core'}),
  legs({'legs', 'glutes', 'core'}),
  conditioning({'cardio', 'full_body', 'core'});

  const DayFocus(this.muscles);

  /// Empty = every muscle group.
  final Set<String> muscles;

  bool matches(Exercise e) => muscles.isEmpty || muscles.contains(e.muscle);
}

/// Day focuses of the week: few days → full body every time; 4 → upper /
/// lower; 5–6 → a three-way split (push / pull / legs for mass, upper /
/// lower / conditioning for the others). Flexibility is always full body.
///
/// Push / pull / legs needs machines for every group, so it is gym-only;
/// at home mass days use upper / lower / full body.
List<DayFocus> weekFocuses(
  int days,
  WorkoutGoal goal, {
  WorkoutType type = WorkoutType.gym,
}) {
  if (days <= 3 || goal == WorkoutGoal.flexibility) {
    return List.filled(days, DayFocus.full);
  }
  final cycle = days == 4
      ? const [DayFocus.upper, DayFocus.lower]
      : goal == WorkoutGoal.gain
      ? type == WorkoutType.gym
            ? const [DayFocus.push, DayFocus.pull, DayFocus.legs]
            : const [DayFocus.upper, DayFocus.lower, DayFocus.full]
      : const [DayFocus.upper, DayFocus.lower, DayFocus.conditioning];
  return [for (var i = 0; i < days; i++) cycle[i % cycle.length]];
}

/// A timed exercise this long (s) is a single continuous bout
/// (a run, a swim, the rowing machine) — one set, the time scales instead.
const _longBoutSeconds = 300;

bool _isLongBout(Exercise e) => (e.seconds ?? 0) >= _longBoutSeconds;

bool _isStretch(Exercise e) => e.type == WorkoutType.yoga;

/// Fits a flexibility day: stretches, light holds, or an easy bout as a
/// warm-up (brisk walk, backstroke).
bool _isLight(Exercise e) =>
    _isStretch(e) || (_isLongBout(e) ? e.kcalPerMin <= 6 : e.kcalPerMin <= 5);

bool _isStrength(Exercise e) =>
    !_isLongBout(e) && e.muscle != 'cardio' && e.type != WorkoutType.yoga;

/// Builds the weekly plan. Deterministic: the same [params] and [catalog]
/// always give the same plan.
///
/// The [catalog] is the whole `exercises` table; the plan mostly uses
/// exercises of `params.type`, plus a few from other types where the goal
/// needs them (bodyweight strength for mass on run / swim / yoga, yoga
/// stretches for flexibility).
List<PlanDay> generatePlan(PlanParams params, List<Exercise> catalog) {
  final days = params.daysPerWeek.clamp(minPlanDays, maxPlanDays);
  final pool = _pool(params, catalog);
  if (pool.isEmpty) return const [];
  final byId = {for (final e in catalog) e.id: e};
  final focuses = weekFocuses(days, params.goal, type: params.type);
  final weekdays = planWeekdays[days]!;
  final perDay = _exercisesPerDay(params, days).clamp(1, pool.length);
  final seen = <DayFocus, int>{};

  return [
    for (var i = 0; i < days; i++)
      () {
        final focus = focuses[i];
        final repeat = seen[focus] = (seen[focus] ?? -1) + 1;
        // Fewer exercises until the day fits [maxDayMinutes].
        late List<PlanItem> items;
        late ({int minutes, int kcal}) est;
        for (var n = perDay; n >= 1; n--) {
          final picked = _withOwnType(
            _pick(pool, focus, params.goal, n, repeat),
            pool,
            params,
          );
          items = _capLongBouts(
            [for (final e in picked) _dose(e, params, days)],
            byId,
            params,
            days,
          );
          est = dayEstimate(items, byId, restSeconds: params.restSeconds);
          if (est.minutes <= maxDayMinutes(params.level)) break;
        }
        return PlanDay(
          day: i + 1,
          weekday: weekdays[i],
          items: items,
          minutes: est.minutes,
          kcal: est.kcal,
        );
      }(),
  ];
}

/// Exercises the plan may use.
List<Exercise> _pool(PlanParams p, List<Exercise> catalog) {
  final own = [
    for (final e in catalog)
      if (e.type == p.type &&
          // Flexibility: only light work of the chosen sport.
          (p.goal != WorkoutGoal.flexibility || _isLight(e)))
        e,
  ];
  final extra = <Exercise>[
    // Mass needs strength work: endurance sports borrow bodyweight moves.
    if (p.goal == WorkoutGoal.gain &&
        const {
          WorkoutType.run,
          WorkoutType.swim,
          WorkoutType.yoga,
        }.contains(p.type))
      for (final e in catalog)
        if (e.type == WorkoutType.home && _isStrength(e)) e,
    // Flexibility always gets yoga stretches.
    if (p.goal == WorkoutGoal.flexibility && p.type != WorkoutType.yoga)
      for (final e in catalog)
        if (_isStretch(e)) e,
  ];
  return [...own, ...extra];
}

/// How many exercises a day has: circuits for weight loss are long, mass
/// days are short and heavy; fewer days a week → longer days.
int _exercisesPerDay(PlanParams p, int days) {
  final base = switch (p.goal) {
    WorkoutGoal.lose => 6,
    WorkoutGoal.gain => 5,
    WorkoutGoal.endurance => 4,
    WorkoutGoal.flexibility => 6,
  };
  final byDays = days <= 2
      ? 1
      : days >= 5
      ? -1
      : 0;
  final byLevel = switch (p.level) {
    WorkoutLevel.beginner => -1,
    WorkoutLevel.intermediate => 0,
    WorkoutLevel.advanced => 1,
  };
  return (base + byDays + byLevel).clamp(2, 8);
}

/// Goal preference of an exercise: higher = picked first.
double _score(Exercise e, WorkoutGoal goal) => switch (goal) {
  WorkoutGoal.lose =>
    e.kcalPerMin + (e.muscle == 'cardio' || e.muscle == 'full_body' ? 3 : 0),
  WorkoutGoal.gain =>
    (_isStrength(e) ? 20 : 0) +
        (e.reps != null ? 5 : 0) +
        (const {'chest', 'back', 'legs'}.contains(e.muscle) ? 3 : 0) +
        (_isStretch(e) ? -30 : 0) -
        e.kcalPerMin / 10,
  WorkoutGoal.endurance =>
    (e.isTimed ? 10 : 0) + (_isLongBout(e) ? 5 : 0) + e.kcalPerMin / 2,
  WorkoutGoal.flexibility =>
    (_isStretch(e) ? 20 : 0) + (e.isTimed ? 5 : 0) - e.kcalPerMin,
};

/// Picks [count] exercises for a day: focus-matching ones first, ordered by
/// the goal score (ties by id, so the result is stable). [shift] rotates
/// the candidates a little so repeated days are not identical.
List<Exercise> _pick(
  List<Exercise> pool,
  DayFocus focus,
  WorkoutGoal goal,
  int count,
  int shift,
) {
  int byScore(Exercise a, Exercise b) {
    final c = _score(b, goal).compareTo(_score(a, goal));
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  final inFocus = [
    for (final e in pool)
      if (focus.matches(e)) e,
  ]..sort(byScore);
  final rest = [
    for (final e in pool)
      if (!focus.matches(e)) e,
  ]..sort(byScore);
  final ranked = [...inFocus, ...rest];

  // Keep the best half fixed, rotate the next ones by [shift].
  final keep = (count / 2).ceil();
  final head = ranked.take(keep).toList();
  final tail = ranked.skip(keep).take(count + 2).toList();
  final rotated = tail.isEmpty
      ? const <Exercise>[]
      : [for (var i = 0; i < tail.length; i++) tail[(i + shift) % tail.length]];
  final picked = [...head, ...rotated].take(count).toList();
  // Workout order: strength / intervals first, long bouts and stretches last.
  int phase(Exercise e) => _isStretch(e)
      ? 2
      : _isLongBout(e)
      ? 1
      : 0;
  final order = {for (var i = 0; i < picked.length; i++) picked[i]: i};
  return picked..sort((a, b) {
    final c = phase(a).compareTo(phase(b));
    return c != 0 ? c : order[a]!.compareTo(order[b]!);
  });
}

/// Makes sure a day has at least one exercise of the chosen sport (mass on
/// a swim plan still swims): the last pick gives way to the best own one.
List<Exercise> _withOwnType(
  List<Exercise> picked,
  List<Exercise> pool,
  PlanParams p,
) {
  if (picked.isEmpty || picked.any((e) => e.type == p.type)) return picked;
  final own = [
    for (final e in pool)
      if (e.type == p.type) e,
  ];
  if (own.isEmpty) return picked;
  own.sort((a, b) {
    final c = _score(b, p.goal).compareTo(_score(a, p.goal));
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return [...picked.take(picked.length - 1), own.first];
}

/// Upper limit of one training day, minutes.
int maxDayMinutes(WorkoutLevel level) => switch (level) {
  WorkoutLevel.beginner => 45,
  WorkoutLevel.intermediate => 60,
  WorkoutLevel.advanced => 80,
};

/// Daily limit of continuous bouts (runs, swims, rowing), minutes.
int longBoutCapMinutes(WorkoutGoal goal, WorkoutLevel level) {
  final base = switch (goal) {
    WorkoutGoal.lose => 40,
    WorkoutGoal.gain => 15,
    WorkoutGoal.endurance => 50,
    WorkoutGoal.flexibility => 15,
  };
  final k = switch (level) {
    WorkoutLevel.beginner => 0.6,
    WorkoutLevel.intermediate => 1.0,
    WorkoutLevel.advanced => 1.3,
  };
  return (base * k).round();
}

/// Scales the long bouts of a day down to [longBoutCapMinutes].
List<PlanItem> _capLongBouts(
  List<PlanItem> items,
  Map<String, Exercise> byId,
  PlanParams p,
  int days,
) {
  bool isLong(PlanItem i) {
    final e = byId[i.exerciseId];
    return e != null && _isLongBout(e);
  }

  final total = items.where(isLong).fold(0, (s, i) => s + (i.seconds ?? 0));
  final cap = longBoutCapMinutes(p.goal, p.level) * 60;
  if (total <= cap) return items;
  final k = cap / total;
  return [
    for (final i in items)
      isLong(i)
          ? PlanItem(
              exerciseId: i.exerciseId,
              sets: i.sets,
              seconds: _roundTo(i.seconds! * k, 60).clamp(120, 5400),
            )
          : i,
  ];
}

/// Sets / reps / seconds of [e] for the goal, level and week load.
PlanItem _dose(Exercise e, PlanParams p, int days) {
  final levelSets = switch (p.level) {
    WorkoutLevel.beginner => -1,
    WorkoutLevel.intermediate => 0,
    WorkoutLevel.advanced => 1,
  };
  final levelVolume = switch (p.level) {
    WorkoutLevel.beginner => 0.8,
    WorkoutLevel.intermediate => 1.0,
    WorkoutLevel.advanced => 1.25,
  };
  // Few days a week → a bit more work per day; many → a bit less.
  final weekVolume = days <= 2
      ? 1.15
      : days >= 5
      ? 0.85
      : 1.0;

  if (_isLongBout(e)) {
    final goalTime = switch (p.goal) {
      WorkoutGoal.lose => 1.25,
      WorkoutGoal.gain => 0.5,
      WorkoutGoal.endurance => 1.6,
      WorkoutGoal.flexibility => 0.5,
    };
    final s = e.seconds! * goalTime * levelVolume * weekVolume;
    return PlanItem(
      exerciseId: e.id,
      sets: 1,
      seconds: _roundTo(s, 60).clamp(120, 5400),
    );
  }

  final (baseSets, repsK, secondsK) = switch (p.goal) {
    WorkoutGoal.lose => (3, 1.4, 1.3),
    WorkoutGoal.gain => (4, 0.7, 1.0),
    WorkoutGoal.endurance => (3, 1.6, 1.5),
    WorkoutGoal.flexibility => (2, 1.0, 1.6),
  };
  final sets = (baseSets + levelSets).clamp(1, 6);
  final k = levelVolume * weekVolume;
  if (e.isTimed) {
    return PlanItem(
      exerciseId: e.id,
      sets: sets,
      seconds: _roundTo(e.seconds! * secondsK * k, 5).clamp(10, 600),
    );
  }
  final reps = ((e.reps ?? 10) * repsK * k).round();
  return PlanItem(
    exerciseId: e.id,
    sets: sets,
    reps: p.goal == WorkoutGoal.gain ? reps.clamp(5, 12) : reps.clamp(5, 50),
  );
}

int _roundTo(double v, int step) => ((v / step).round() * step);

/// Week totals of a plan.
({int minutes, int kcal}) weekTotals(List<PlanDay> days) => (
  minutes: days.fold(0, (s, d) => s + d.minutes),
  kcal: days.fold(0, (s, d) => s + d.kcal),
);
