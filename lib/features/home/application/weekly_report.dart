import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'sino_index.dart';

/// The week in numbers for `/report`: the last 7 days (today included —
/// it's still going) and the 7 before them for comparison.
class WeeklyReport {
  const WeeklyReport({
    required this.days,
    required this.average,
    required this.previousAverage,
    required this.best,
    required this.glasses,
    required this.waterGoalDays,
    required this.waterDays,
    required this.workouts,
    required this.dosesTaken,
    required this.dosesDue,
    required this.steps,
    required this.stepsDays,
  });

  /// Oldest first, today last.
  final List<SinoDay> days;

  /// Average index of the days with data; `null` — nothing logged.
  final int? average;

  /// Same for the week before; `null` — no data then.
  final int? previousAverage;

  /// Day with the highest index (the later one on a tie).
  final SinoDay? best;

  final int glasses;

  /// Days with 8+ glasses.
  final int waterGoalDays;

  /// Days with any water logged.
  final int waterDays;
  final int workouts;
  final int dosesTaken;

  /// Doses whose time has come (or that were taken early).
  final int dosesDue;
  final int steps;
  final int stepsDays;

  DateTime get from => days.first.date;
  DateTime get to => days.last.date;

  /// Index change against last week; `null` when either week is empty.
  int? get delta => average == null || previousAverage == null
      ? null
      : average! - previousAverage!;

  /// Taken / due doses, 0..1; `null` — no doses.
  double? get dosesShare => dosesDue == 0 ? null : dosesTaken / dosesDue;

  double? get glassesPerDay => waterDays == 0 ? null : glasses / waterDays;

  int? get stepsPerDay => stepsDays == 0 ? null : (steps / stepsDays).round();

  bool get isEmpty => average == null;
}

int? _average(Iterable<SinoDay> days) {
  final scores = [for (final d in days) ?d.index?.score];
  if (scores.isEmpty) return null;
  return (scores.reduce((a, b) => a + b) / scores.length).round();
}

/// Builds the report from [history] (oldest first, today last, ≥ 7 days).
WeeklyReport buildWeeklyReport(List<SinoDay> history, {required DateTime now}) {
  final week = history.sublist(history.length - 7);
  final before = history.length >= 14
      ? history.sublist(history.length - 14, history.length - 7)
      : const <SinoDay>[];

  SinoDay? best;
  for (final d in week) {
    final s = d.index?.score;
    if (s != null && s >= (best?.index?.score ?? -1)) best = d;
  }

  var glasses = 0, goalDays = 0, waterDays = 0, workouts = 0;
  var taken = 0, due = 0, steps = 0, stepsDays = 0;
  for (final d in week) {
    final i = d.input;
    if (i.glasses != null) {
      waterDays++;
      glasses += i.glasses!;
      if (i.glasses! >= SinoTargets.glasses) goalDays++;
    }
    workouts += i.workouts;
    for (final dose in i.doses) {
      if (dose.taken || !dose.at.isAfter(now)) due++;
      if (dose.taken) taken++;
    }
    if (i.steps != null) {
      stepsDays++;
      steps += i.steps!;
    }
  }

  return WeeklyReport(
    days: week,
    average: _average(week),
    previousAverage: _average(before),
    best: best,
    glasses: glasses,
    waterGoalDays: goalDays,
    waterDays: waterDays,
    workouts: workouts,
    dosesTaken: taken,
    dosesDue: due,
    steps: steps,
    stepsDays: stepsDays,
  );
}

final weeklyReportProvider = FutureProvider<WeeklyReport>((ref) async {
  final history = await ref.watch(sinoHistoryProvider.future);
  return buildWeeklyReport(history, now: ref.watch(sinoClockProvider)());
});

/// Shares the report card PNG with a caption (system share sheet).
/// Overridden in tests.
typedef ReportSharer = Future<void> Function(Uint8List png, String text);

final reportSharerProvider = Provider<ReportSharer>(
  (_) =>
      (png, text) => SharePlus.instance.share(
        ShareParams(
          text: text,
          files: [
            XFile.fromData(
              png,
              mimeType: 'image/png',
              name: 'sino-hisobot.png',
            ),
          ],
        ),
      ),
);
