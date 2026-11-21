/// Today's steps from the phone's step counter (Sprint 2.0, S2-3), without
/// Flutter.
///
/// The sensor reports a cumulative count since the phone booted. [StepsDay]
/// turns it into «steps today»: the first reading of a day is the baseline
/// (steps before the app saw the day are not known), a reboot (the count
/// drops) keeps what was already counted.
library;

/// Daily goal on the ring.
const stepsGoal = 8000;

/// Rough averages for the hints under the ring (not shown as exact).
const stepLengthM = 0.75;
const kcalPerStep = 0.04;

/// Steps of one calendar day, stored in prefs between app runs.
class StepsDay {
  const StepsDay({
    required this.day,
    required this.baseline,
    required this.lastCount,
    this.carried = 0,
  });

  /// Local date (no time).
  final DateTime day;

  /// Sensor count at the start of counting for [day].
  final int baseline;

  /// Last sensor count seen.
  final int lastCount;

  /// Steps counted before a reboot on the same day.
  final int carried;

  int get steps => carried + (lastCount - baseline).clamp(0, 1 << 31);

  Map<String, dynamic> toJson() => {
    'day': _iso(day),
    'baseline': baseline,
    'last': lastCount,
    'carried': carried,
  };

  static StepsDay? tryFromJson(Map<String, dynamic>? m) {
    if (m == null) return null;
    try {
      return StepsDay(
        day: DateTime.parse(m['day'] as String),
        baseline: (m['baseline'] as num).toInt(),
        lastCount: (m['last'] as num).toInt(),
        carried: (m['carried'] as num? ?? 0).toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is StepsDay &&
      other.day == day &&
      other.baseline == baseline &&
      other.lastCount == lastCount &&
      other.carried == carried;

  @override
  int get hashCode => Object.hash(day, baseline, lastCount, carried);

  @override
  String toString() => 'StepsDay(${_iso(day)}, $steps)';
}

DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Result of a sensor reading: today's state and, when a day has just
/// ended, its final total to save.
typedef StepsUpdate = ({StepsDay today, StepsDay? finished});

/// Applies the cumulative sensor [count] seen at [now] to [prev].
StepsUpdate applyStepCount(StepsDay? prev, int count, DateTime now) {
  final today = dateOnly(now);
  if (prev == null) {
    return (
      today: StepsDay(day: today, baseline: count, lastCount: count),
      finished: null,
    );
  }
  if (prev.day != today) {
    // New day. Steps between the last reading and now can't be split by
    // day; start today from this reading.
    return (
      today: StepsDay(day: today, baseline: count, lastCount: count),
      finished: prev.day.isBefore(today) ? prev : null,
    );
  }
  if (count < prev.lastCount) {
    // The phone rebooted: the counter started again from 0.
    return (
      today: StepsDay(
        day: today,
        baseline: 0,
        lastCount: count,
        carried: prev.steps,
      ),
      finished: null,
    );
  }
  return (
    today: StepsDay(
      day: today,
      baseline: prev.baseline,
      lastCount: count,
      carried: prev.carried,
    ),
    finished: null,
  );
}

/// Whether today's total should be written to `vitals` now: something
/// changed and either [minGap] passed since the last write or [minDelta]
/// steps were added.
bool shouldSaveSteps({
  required int steps,
  required int? savedSteps,
  required DateTime now,
  required DateTime? savedAt,
  Duration minGap = const Duration(minutes: 5),
  int minDelta = 500,
}) {
  if (steps <= 0 || steps == savedSteps) return false;
  if (savedSteps == null || savedAt == null) return true;
  if (dateOnly(savedAt) != dateOnly(now)) return true;
  return now.difference(savedAt) >= minGap || steps - savedSteps >= minDelta;
}

double stepsKm(int steps) => steps * stepLengthM / 1000;

int stepsKcal(int steps) => (steps * kcalPerStep).round();
