import '../data/models.dart';

/// Average time of one repetition, seconds.
const secondsPerRep = 3;

/// Working time of [item] in seconds: sets × (seconds or reps × 3 s).
/// Falls back to the catalog defaults of [exercise].
int itemSeconds(PlanItem item, Exercise exercise) {
  final seconds = item.seconds ?? exercise.seconds;
  final reps = item.reps ?? exercise.reps;
  final perSet = seconds ?? (reps ?? 0) * secondsPerRep;
  return item.sets * perSet;
}

/// ~kcal of [item]: `kcal_per_min × minutes of work`.
double itemKcal(PlanItem item, Exercise exercise) =>
    exercise.kcalPerMin * itemSeconds(item, exercise) / 60;

/// Rest between sets is light activity, not zero: ~2 kcal per minute.
const restKcalPerMin = 2.0;

/// Minutes and ~kcal of a list of items; unknown exercise ids are
/// skipped. [restSeconds] between sets adds time and
/// [restKcalPerMin] calories (single-set bouts have no rest).
({int minutes, int kcal}) dayEstimate(
  List<PlanItem> items,
  Map<String, Exercise> catalog, {
  int restSeconds = 0,
}) {
  var seconds = 0;
  var kcal = 0.0;
  for (final i in items) {
    final e = catalog[i.exerciseId];
    if (e == null) continue;
    final rest = i.sets > 1 ? restSeconds * i.sets : 0;
    seconds += itemSeconds(i, e) + rest;
    kcal += itemKcal(i, e) + restKcalPerMin * rest / 60;
  }
  return (minutes: (seconds / 60).round(), kcal: kcal.round());
}

/// Streak: consecutive days with at least one session, counted back from
/// today. A streak that ended yesterday still counts (today is not over).
int streakDays(Iterable<WorkoutSession> sessions, DateTime now) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final days = {for (final s in sessions) day(s.finishedAt)};
  var cursor = day(now);
  if (!days.contains(cursor)) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}

/// The next training day of a plan and its date.
///
/// Today counts while no session is finished today; otherwise the search
/// starts tomorrow and wraps into next week. Days without a weekday are
/// taken in order. `null` for an empty plan.
({PlanDay day, DateTime date})? nextWorkout(
  List<PlanDay> days,
  DateTime now,
  Iterable<WorkoutSession> sessions,
) {
  if (days.isEmpty) return null;
  final today = DateTime(now.year, now.month, now.day);
  bool sameDay(DateTime a) =>
      a.year == today.year && a.month == today.month && a.day == today.day;
  final doneToday = sessions.any((s) => sameDay(s.finishedAt));
  final start = doneToday ? 1 : 0;

  final dated = [
    for (final d in days)
      if (d.weekday != null) d,
  ];
  if (dated.isEmpty) {
    return (
      day: days.first,
      date: DateTime(today.year, today.month, today.day + start),
    );
  }
  for (var offset = start; offset < start + 7; offset++) {
    final weekday = (today.weekday - 1 + offset) % 7 + 1;
    for (final d in dated) {
      if (d.weekday == weekday) {
        return (
          day: d,
          date: DateTime(today.year, today.month, today.day + offset),
        );
      }
    }
  }
  return null;
}
