import 'dart:math' as math;

/// Phase of the 4-7-8 breathing: inhale 4 s, hold 7 s, exhale 8 s.
enum BreathPhase {
  inhale(4),
  hold(7),
  exhale(8);

  const BreathPhase(this.seconds);

  final int seconds;
}

/// One cycle, seconds (4 + 7 + 8).
const breathCycleSeconds = 19;

/// Cycles the user can choose; 4 is the classic recommendation.
const breathCycleOptions = [4, 6, 8];

/// Circle scale: small after exhale, full after inhale.
const breathMinScale = 0.55;
const breathMaxScale = 1.0;

/// Where the exercise is after [elapsed].
class BreathState {
  const BreathState({
    required this.phase,
    required this.cycle,
    required this.secondsLeft,
    required this.phaseProgress,
    required this.done,
  });

  final BreathPhase phase;

  /// 1-based cycle.
  final int cycle;

  /// Whole seconds left of the phase (the big number: 4, 3, 2, 1).
  final int secondsLeft;

  /// 0…1 within the phase.
  final double phaseProgress;
  final bool done;

  /// Circle scale: grows on inhale, stays on hold, shrinks on exhale
  /// (ease in-out, so the motion feels like breath).
  double get scale {
    double ease(double t) => 0.5 - math.cos(math.pi * t) / 2;
    const span = breathMaxScale - breathMinScale;
    return switch (phase) {
      BreathPhase.inhale => breathMinScale + span * ease(phaseProgress),
      BreathPhase.hold => breathMaxScale,
      BreathPhase.exhale => breathMaxScale - span * ease(phaseProgress),
    };
  }
}

/// Pure: state of an exercise of [cycles] cycles after [elapsed].
BreathState breathStateAt(Duration elapsed, int cycles) {
  final total = cycles * breathCycleSeconds * 1000;
  final ms = elapsed.inMilliseconds.clamp(0, total);
  if (ms >= total) {
    return BreathState(
      phase: BreathPhase.exhale,
      cycle: cycles,
      secondsLeft: 0,
      phaseProgress: 1,
      done: true,
    );
  }
  final cycle = ms ~/ (breathCycleSeconds * 1000);
  var inCycle = ms - cycle * breathCycleSeconds * 1000;
  for (final p in BreathPhase.values) {
    final len = p.seconds * 1000;
    if (inCycle < len) {
      return BreathState(
        phase: p,
        cycle: cycle + 1,
        secondsLeft: ((len - inCycle) / 1000).ceil(),
        phaseProgress: inCycle / len,
        done: false,
      );
    }
    inCycle -= len;
  }
  throw StateError('unreachable');
}

/// Whole duration of [cycles] cycles.
Duration breathTotal(int cycles) =>
    Duration(seconds: cycles * breathCycleSeconds);
