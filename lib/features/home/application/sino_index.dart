import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/user.dart';
import '../data/sino_data.dart';

/// Parts of the Sino index and their weights (sum = 100).
enum SinoPart {
  nutrition(25),
  water(20),
  medicines(20),
  activity(20),
  sleep(15);

  const SinoPart(this.weight);
  final int weight;
}

/// Daily targets.
abstract final class SinoTargets {
  static const glasses = 8;
  static const steps = 8000;
  static const sleepLow = 7.0;
  static const sleepHigh = 9.0;

  /// Fallback calorie goal when the profile is incomplete.
  static const kcal = 2000;
}

/// What happened on one local day — the input of [computeSinoIndex].
/// `null` / empty means "no data", not "zero".
class SinoDayInput {
  const SinoDayInput({
    required this.date,
    this.kcal,
    this.glasses,
    this.doses = const [],
    this.steps,
    this.workouts = 0,
    this.sleepHours,
  });

  final DateTime date;

  /// Eaten kcal; `null` — nothing logged.
  final double? kcal;

  /// Water glasses; `null` — no `water_logs` row.
  final int? glasses;

  /// The user's own scheduled doses of the day.
  final List<SinoDose> doses;

  /// Steps of the day (largest `vitals.steps` value).
  final int? steps;

  /// Finished workouts.
  final int workouts;

  /// Hours of last night's sleep (latest `vitals.sleep` of the day).
  final double? sleepHours;
}

class SinoDose {
  const SinoDose({required this.at, required this.taken});
  final DateTime at;
  final bool taken;
}

/// Score of one part: [score] 0..1, [value] / [target] for display
/// (kcal, glasses, doses, steps, hours).
class SinoPartResult {
  const SinoPartResult({
    required this.part,
    required this.score,
    required this.value,
    required this.target,
    required this.share,
  });

  final SinoPart part;
  final double score;
  final num value;
  final num target;

  /// Effective weight 0..1 after redistributing parts without data.
  final double share;

  /// Points this part adds to the 0–100 index.
  double get points => score * share * 100;
}

class SinoIndex {
  const SinoIndex({required this.date, required this.parts});

  final DateTime date;

  /// Only parts that had data, in [SinoPart] order.
  final List<SinoPartResult> parts;

  int get score =>
      parts.fold<double>(0, (s, p) => s + p.points).round().clamp(0, 100);

  SinoPartResult? part(SinoPart p) {
    for (final r in parts) {
      if (r.part == p) return r;
    }
    return null;
  }

  /// Parts without data today (excluded, their weight redistributed).
  List<SinoPart> get missing => [
    for (final p in SinoPart.values)
      if (part(p) == null) p,
  ];
}

/// Share of the day that has passed for the targets (by 21:00 — the whole
/// day). Past days count as complete. Never below 0.25 so early mornings
/// aren't judged by tiny numbers.
double dayProgress(DateTime day, DateTime now) {
  final d = dateOnly(day), today = dateOnly(now);
  if (d.isBefore(today)) return 1;
  if (d.isAfter(today)) return 0.25;
  final hours = now.hour + now.minute / 60;
  return ((hours - 7) / 14).clamp(0.25, 1.0);
}

/// Sleep hours → 0..1: 7–9 h is 1, 4 h or less is 0, 12 h or more is 0.
double sleepScore(double h) {
  if (h < SinoTargets.sleepLow) return ((h - 4) / 3).clamp(0.0, 1.0);
  if (h > SinoTargets.sleepHigh) return (1 - (h - 9) / 3).clamp(0.0, 1.0);
  return 1;
}

/// Sino index 0–100 for [input]; `null` when the day has no data at all.
///
/// - nutrition 25: eaten vs. the calorie goal expected by now; more than
///   110 % of the whole-day goal loses points (150 % → 0)
/// - water 20: glasses vs. 8 expected by now
/// - medicines 20: taken / due doses (a dose is due once its time passed)
/// - activity 20: a finished workout = 1, else steps vs. 8000 expected by now
/// - sleep 15: 7–9 h = 1
///
/// Parts without data are left out and the weights of the others are
/// scaled up to 100. Not a diagnosis («Shifokor maslahatini almashtirmaydi»).
SinoIndex? computeSinoIndex(
  SinoDayInput input, {
  required int kcalGoal,
  required DateTime now,
}) {
  final e = dayProgress(input.date, now);
  final raw = <SinoPart, (double, num, num)>{};

  final kcal = input.kcal;
  if (kcal != null && kcalGoal > 0) {
    final soFar = math.min(1.0, kcal / (kcalGoal * e));
    final over = kcal / kcalGoal;
    final overScore = over <= 1.1 ? 1.0 : (1 - (over - 1.1) / 0.4);
    raw[SinoPart.nutrition] = (
      math.min(soFar, overScore).clamp(0.0, 1.0),
      kcal.round(),
      kcalGoal,
    );
  }

  final glasses = input.glasses;
  if (glasses != null) {
    raw[SinoPart.water] = (
      math.min(1.0, glasses / (SinoTargets.glasses * e)),
      glasses,
      SinoTargets.glasses,
    );
  }

  final due = input.doses.where((d) => d.taken || !d.at.isAfter(now)).toList();
  if (due.isNotEmpty) {
    final taken = due.where((d) => d.taken).length;
    raw[SinoPart.medicines] = (taken / due.length, taken, due.length);
  }

  final steps = input.steps;
  if (input.workouts > 0 || steps != null) {
    final stepScore = steps == null
        ? 0.0
        : math.min(1.0, steps / (SinoTargets.steps * e));
    raw[SinoPart.activity] = (
      input.workouts > 0 ? 1.0 : stepScore,
      steps ?? 0,
      SinoTargets.steps,
    );
  }

  final sleep = input.sleepHours;
  if (sleep != null) {
    raw[SinoPart.sleep] = (sleepScore(sleep), sleep, SinoTargets.sleepLow);
  }

  if (raw.isEmpty) return null;
  final total = raw.keys.fold<int>(0, (s, p) => s + p.weight);
  return SinoIndex(
    date: dateOnly(input.date),
    parts: [
      for (final p in SinoPart.values)
        if (raw[p] case (final score, final value, final target))
          SinoPartResult(
            part: p,
            score: score,
            value: value,
            target: target,
            share: p.weight / total,
          ),
    ],
  );
}

/// Collects one day's input from the raw rows.
SinoDayInput sinoDayInput(SinoRaw raw, DateTime day) {
  final d = dateOnly(day);
  bool same(DateTime t) => dateOnly(t) == d;

  final food = raw.food.where((f) => same(f.date)).toList();
  final water = raw.water.where((w) => same(w.date)).toList();

  final takenIds = {
    for (final l in raw.doseLogs)
      if (same(l.takenAt)) l.reminderId,
  };
  final doses = [
    for (final r in raw.reminders)
      if (r.active && r.memberId == null && r.days.contains(d.weekday))
        SinoDose(
          at: d.add(Duration(minutes: r.minutes)),
          taken: takenIds.contains(r.id),
        ),
  ]..sort((a, b) => a.at.compareTo(b.at));

  final steps = [
    for (final v in raw.vitals)
      if (v.kind == 'steps' && same(v.measuredAt)) v.value,
  ];
  final sleeps = [
    for (final v in raw.vitals)
      if (v.kind == 'sleep' && same(v.measuredAt)) v,
  ]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

  return SinoDayInput(
    date: d,
    kcal: food.isEmpty ? null : food.fold<double>(0, (s, f) => s + f.kcal),
    glasses: water.isEmpty
        ? null
        : water.map((w) => w.glasses).reduce(math.max),
    doses: doses,
    steps: steps.isEmpty ? null : steps.reduce(math.max).round(),
    workouts: raw.sessions.where(same).length,
    sleepHours: sleeps.isEmpty ? null : sleeps.last.value,
  );
}

/// Daily calorie goal from the profile — Mifflin–St Jeor (average sex
/// constant, the profile has no sex) × 1.375 light activity, rounded to 10.
int sinoKcalGoal(UserProfile? p, {required int year}) {
  final w = p?.weightKg, h = p?.heightCm, born = p?.birthYear;
  if (w == null || h == null || born == null || w <= 0 || h <= 0) {
    return SinoTargets.kcal;
  }
  final age = (year - born).clamp(10, 100);
  final bmr = 10 * w + 6.25 * h - 5 * age - 78;
  return ((bmr * 1.375) / 10).round() * 10;
}

/// One day of the week view.
class SinoDay {
  const SinoDay({required this.input, required this.index});
  final SinoDayInput input;
  final SinoIndex? index;
  DateTime get date => input.date;
}

/// "Now" for the index; overridden in tests.
final sinoClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// The last 7 days, oldest first, today last.
final sinoWeekProvider = FutureProvider<List<SinoDay>>((ref) async {
  final now = ref.watch(sinoClockProvider)();
  final today = dateOnly(now);
  final from = today.subtract(const Duration(days: 6));
  final profile = await ref.watch(currentUserProvider.future);
  final goal = sinoKcalGoal(profile, year: now.year);
  final raw = await ref
      .watch(sinoDataRepositoryProvider)
      .load(from: from, to: today);
  return [
    for (var i = 0; i < 7; i++)
      () {
        final input = sinoDayInput(raw, from.add(Duration(days: i)));
        return SinoDay(
          input: input,
          index: computeSinoIndex(input, kcalGoal: goal, now: now),
        );
      }(),
  ];
});

/// Today's index; `null` when nothing is logged today.
final sinoTodayProvider = FutureProvider<SinoDay>((ref) async {
  final week = await ref.watch(sinoWeekProvider.future);
  return week.last;
});
