/// Models of the workouts feature (tables `exercises`, `workout_plans`,
/// `workout_sessions`). Hand-written `fromJson`/`toJson`, no codegen.
library;

/// Kind of training — `exercises.type`.
enum WorkoutType {
  home,
  gym,
  run,
  yoga,
  swim,
  kurash;

  static WorkoutType fromName(String? s) =>
      values.firstWhere((t) => t.name == s, orElse: () => WorkoutType.home);
}

/// A row of the `exercises` catalog. Exactly one of [reps] / [seconds].
class Exercise {
  const Exercise({
    required this.id,
    required this.type,
    required this.name,
    this.slug,
    this.muscle,
    this.hint = const {},
    this.reps,
    this.seconds,
    this.kcalPerMin = 5,
  });

  final String id;

  /// Asset-only readable id (`push_ups`); `null` for rows from Supabase.
  final String? slug;
  final WorkoutType type;

  /// legs | full_body | cardio | back | core | shoulders | chest | arms | glutes
  final String? muscle;

  /// `{uz, ru, en}` — show with `context.trMap`.
  final Map<String, dynamic> name;
  final Map<String, dynamic> hint;
  final int? reps;
  final int? seconds;
  final double kcalPerMin;

  bool get isTimed => seconds != null;

  factory Exercise.fromJson(Map<String, dynamic> m) => Exercise(
    id: m['id'] as String,
    slug: m['slug'] as String?,
    type: WorkoutType.fromName(m['type'] as String?),
    muscle: m['muscle'] as String?,
    name: Map<String, dynamic>.from(m['name'] as Map? ?? const {}),
    hint: Map<String, dynamic>.from(m['hint'] as Map? ?? const {}),
    reps: (m['reps'] as num?)?.toInt(),
    seconds: (m['seconds'] as num?)?.toInt(),
    kcalPerMin: (m['kcal_per_min'] as num?)?.toDouble() ?? 5,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (slug != null) 'slug': slug,
    'type': type.name,
    'muscle': muscle,
    'name': name,
    'hint': hint,
    'reps': reps,
    'seconds': seconds,
    'kcal_per_min': kcalPerMin,
  };
}

/// One exercise in a plan day: [sets] × ([reps] or [seconds]).
class PlanItem {
  const PlanItem({
    required this.exerciseId,
    this.sets = 1,
    this.reps,
    this.seconds,
  });

  final String exerciseId;
  final int sets;
  final int? reps;
  final int? seconds;

  factory PlanItem.fromJson(Map<String, dynamic> m) => PlanItem(
    exerciseId: m['exercise_id'] as String,
    sets: (m['sets'] as num?)?.toInt() ?? 1,
    reps: (m['reps'] as num?)?.toInt(),
    seconds: (m['seconds'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'exercise_id': exerciseId,
    'sets': sets,
    if (reps != null) 'reps': reps,
    if (seconds != null) 'seconds': seconds,
  };
}

/// One training day of the weekly plan (`plan` jsonb is a list of these).
class PlanDay {
  const PlanDay({
    required this.day,
    required this.items,
    this.weekday,
    this.minutes = 0,
    this.kcal = 0,
  });

  /// 1-based number of the training day in the week.
  final int day;

  /// 1 = Monday … 7 = Sunday (as `reminders.days`); `null` = any day.
  final int? weekday;
  final List<PlanItem> items;
  final int minutes;
  final int kcal;

  factory PlanDay.fromJson(Map<String, dynamic> m) => PlanDay(
    day: (m['day'] as num).toInt(),
    weekday: (m['weekday'] as num?)?.toInt(),
    items: [
      for (final i in m['items'] as List? ?? const [])
        PlanItem.fromJson(Map<String, dynamic>.from(i as Map)),
    ],
    minutes: (m['minutes'] as num?)?.toInt() ?? 0,
    kcal: (m['kcal'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    if (weekday != null) 'weekday': weekday,
    'items': [for (final i in items) i.toJson()],
    'minutes': minutes,
    'kcal': kcal,
  };
}

/// A row of `workout_plans`. [params] are the generator inputs
/// (type, goal, level, days per week…), [days] — the generated week.
class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.params,
    required this.days,
    this.createdAt,
  });

  final String id;
  final Map<String, dynamic> params;
  final List<PlanDay> days;
  final DateTime? createdAt;

  factory WorkoutPlan.fromJson(Map<String, dynamic> m) => WorkoutPlan(
    id: m['id'] as String,
    params: Map<String, dynamic>.from(m['params'] as Map? ?? const {}),
    days: [
      for (final d in m['plan'] as List? ?? const [])
        PlanDay.fromJson(Map<String, dynamic>.from(d as Map)),
    ],
    createdAt: m['created_at'] == null
        ? null
        : DateTime.parse(m['created_at'] as String).toLocal(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'params': params,
    'plan': [for (final d in days) d.toJson()],
    if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
  };
}

/// A row of `workout_sessions` — a finished workout.
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.finishedAt,
    this.planDay,
    this.kcal = 0,
  });

  final String id;
  final int? planDay;
  final double kcal;
  final DateTime finishedAt;

  factory WorkoutSession.fromJson(Map<String, dynamic> m) => WorkoutSession(
    id: m['id'] as String,
    planDay: (m['plan_day'] as num?)?.toInt(),
    kcal: (m['kcal'] as num?)?.toDouble() ?? 0,
    finishedAt: DateTime.parse(m['finished_at'] as String).toLocal(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'plan_day': planDay,
    'kcal': kcal,
    'finished_at': finishedAt.toUtc().toIso8601String(),
  };
}
