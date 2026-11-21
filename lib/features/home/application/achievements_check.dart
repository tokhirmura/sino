import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/achievements.dart';
import '../data/sino_data.dart';
import 'sino_index.dart';

/// Daily targets of the badges.
abstract final class BadgeTargets {
  static const waterDays = 7;
  static const medsDays = 3;
  static const steps = 10000;
  static const index = 90;

  /// Parts with data needed for «Indeks 90+» (one logged part alone
  /// gives 100 — too easy).
  static const indexParts = 3;
  static const streakDays = 7;
}

/// Badges earned by the data of [history] (oldest first, today last).
///
/// Today counts only when it's settled: 8 glasses already drunk, every
/// dose of the day taken, index 90+ only after 21:00 (earlier the targets
/// are scaled down to the passed part of the day and the index is generous)
/// and with at least [BadgeTargets.indexParts] parts logged.
Set<Achievement> earnedAchievements(
  List<SinoDay> history, {
  required DateTime now,
  required bool hasReservation,
}) {
  final today = dateOnly(now);
  bool settled(SinoDay d) =>
      d.input.date.isBefore(today) || dayProgress(d.input.date, now) >= 1;

  int longestRun(bool Function(SinoDay) ok) {
    var best = 0, run = 0;
    for (final d in history) {
      run = ok(d) ? run + 1 : 0;
      if (run > best) best = run;
    }
    return best;
  }

  return {
    if (history.any((d) => d.input.workouts > 0)) Achievement.firstWorkout,
    if (longestRun((d) => (d.input.glasses ?? 0) >= SinoTargets.glasses) >=
        BadgeTargets.waterDays)
      Achievement.water7,
    if (longestRun(
          (d) =>
              d.input.doses.isNotEmpty && d.input.doses.every((x) => x.taken),
        ) >=
        BadgeTargets.medsDays)
      Achievement.meds3,
    if (hasReservation) Achievement.firstReservation,
    if (history.any((d) => (d.input.steps ?? 0) >= BadgeTargets.steps))
      Achievement.steps10k,
    if (history.any(
      (d) =>
          settled(d) &&
          (d.index?.parts.length ?? 0) >= BadgeTargets.indexParts &&
          d.index!.score >= BadgeTargets.index,
    ))
      Achievement.index90,
    if (longestRun((d) => (d.index?.score ?? 0) >= sinoStreakThreshold) >=
        BadgeTargets.streakDays)
      Achievement.streak7,
    if (history.any((d) => d.index != null && d.index!.missing.isEmpty))
      Achievement.fullDay,
  };
}

/// Badges unlocked by this check — earned now and not saved before. They
/// are saved right away (so each is celebrated once); home listens and
/// shows confetti. Recomputed whenever [sinoHistoryProvider] reloads.
final newAchievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final history = await ref.watch(sinoHistoryProvider.future);
  final now = ref.watch(sinoClockProvider)();
  final data = ref.watch(sinoDataRepositoryProvider);
  final repo = ref.watch(achievementsRepositoryProvider);

  final earned = earnedAchievements(
    history,
    now: now,
    hasReservation: await data.hasReservation(),
  );
  final saved = await repo.unlocked();
  final fresh = [
    for (final a in Achievement.values)
      if (earned.contains(a) && !saved.containsKey(a)) a,
  ];
  if (fresh.isEmpty) return const [];
  await repo.unlock(fresh, now);
  if (ref.mounted) ref.invalidate(achievementsProvider);
  return fresh;
});

/// Show the celebration (dialog with confetti) for new badges. Off under
/// `flutter test`: confetti runs on the wall clock and a dialog over home
/// would cover other features' screens in their app-level tests; home
/// tests turn it on explicitly.
final achievementCelebrationProvider = Provider<bool>(
  (_) => !Platform.environment.containsKey('FLUTTER_TEST'),
);
