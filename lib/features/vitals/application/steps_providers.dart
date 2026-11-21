import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/prefs.dart';
import '../data/models.dart';
import '../data/step_sensor.dart';
import '../data/vitals_repository.dart';
import 'steps.dart';
import 'vitals_providers.dart';

enum StepsStatus {
  /// Listening, no reading yet.
  starting,

  /// Readings arrive.
  counting,

  /// No reading for [stepsSilenceLimit]: most likely no «physical
  /// activity» permission (Android sends nothing then).
  silent,

  /// No step counter on this device (emulator).
  unavailable,
}

/// After this long without a reading the card suggests the permission.
const stepsSilenceLimit = Duration(seconds: 5);

/// What the steps card shows.
class StepsView {
  const StepsView(this.status, this.steps);

  final StepsStatus status;

  /// Today's steps; `null` — not known yet.
  final int? steps;

  double get progress => (steps ?? 0) / stepsGoal;

  @override
  bool operator ==(Object other) =>
      other is StepsView && other.status == status && other.steps == steps;

  @override
  int get hashCode => Object.hash(status, steps);

  @override
  String toString() => 'StepsView($status, $steps)';
}

/// Today's steps from the sensor, kept in prefs between runs; the day's
/// total goes to `vitals` (kind `steps`, one row per day, updated in place)
/// — the lead reads it for the Sino index.
class StepsNotifier extends Notifier<StepsView> {
  /// prefs: today's [StepsDay].
  static const dayKey = 'vitals.steps_day';

  /// prefs: `{"day", "id", "steps", "at"}` of the `vitals` row written for
  /// a day.
  static const rowKey = 'vitals.steps_row';

  StreamSubscription<int>? _sub;
  Timer? _silence;
  StepsDay? _day;

  /// One write at a time; a newer value waits for it.
  Future<void>? _writing;

  @override
  StepsView build() {
    ref.onDispose(_stop);
    final sensor = ref.watch(stepSensorProvider);
    _day = StepsDay.tryFromJson(_readJson(dayKey));
    final known = _day?.day == dateOnly(DateTime.now()) ? _day!.steps : null;
    _listen(sensor);
    return StepsView(StepsStatus.starting, known);
  }

  /// Listens again — after the user allowed the permission in settings.
  void restart() {
    if (state.status == StepsStatus.counting) return;
    _stop();
    state = StepsView(StepsStatus.starting, state.steps);
    _listen(ref.read(stepSensorProvider));
  }

  /// Saves today's total now (the app goes to the background).
  Future<void> flush() async {
    final d = _day;
    if (d != null && d.day == dateOnly(DateTime.now())) {
      await _save(d, force: true);
    }
  }

  /// Completes when the pending `vitals` write (if any) is done (tests).
  @visibleForTesting
  Future<void> get idle async {
    while (_writing != null) {
      await _writing;
    }
  }

  Future<void> openSettings() => ref.read(stepSensorProvider).openSettings();

  void _listen(StepSensor sensor) {
    _sub = sensor.counts().listen(
      _onCount,
      onError: (Object e) {
        _silence?.cancel();
        state = StepsView(StepsStatus.unavailable, state.steps);
      },
    );
    _silence = Timer(stepsSilenceLimit, () {
      if (state.status == StepsStatus.starting) {
        state = StepsView(StepsStatus.silent, state.steps);
      }
    });
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _silence?.cancel();
    _silence = null;
  }

  void _onCount(int count) {
    _silence?.cancel();
    final now = DateTime.now();
    final u = applyStepCount(_day, count, now);
    _day = u.today;
    unawaited(_prefs.setString(dayKey, jsonEncode(u.today.toJson())));
    state = StepsView(StepsStatus.counting, u.today.steps);
    final finished = u.finished;
    if (finished != null) unawaited(_save(finished, force: true));
    unawaited(_save(u.today));
  }

  /// Writes [d]'s total to `vitals` (throttled unless [force]); offline or
  /// signed out — skipped silently, the next reading tries again.
  Future<void> _save(StepsDay d, {bool force = false}) async {
    while (_writing != null) {
      await _writing;
    }
    final done = Completer<void>();
    _writing = done.future;
    try {
      await _write(d, force: force);
    } catch (_) {
      // Not signed in / no network: keep counting, try later.
    } finally {
      _writing = null;
      done.complete();
    }
  }

  Future<void> _write(StepsDay d, {required bool force}) async {
    final row = _readJson(rowKey);
    final sameDay = row?['day'] == d.toJson()['day'];
    final savedSteps = sameDay ? (row!['steps'] as num?)?.toInt() : null;
    final savedAt = sameDay
        ? DateTime.tryParse(row!['at'] as String? ?? '')
        : null;
    final now = DateTime.now();
    final isToday = d.day == dateOnly(now);
    if (d.steps <= 0 || d.steps == savedSteps) return;
    if (!force &&
        !shouldSaveSteps(
          steps: d.steps,
          savedSteps: savedSteps,
          now: now,
          savedAt: savedAt,
        )) {
      return;
    }
    // A finished day is stamped at its end, today — now.
    final at = isToday
        ? now
        : DateTime(d.day.year, d.day.month, d.day.day, 23, 59);
    final repo = ref.read(vitalsRepositoryProvider);
    final value = d.steps.toDouble();
    String? id = sameDay ? row!['id'] as String? : null;
    if (id == null || !await repo.update(id, value: value, measuredAt: at)) {
      id = (await repo.add(
        kind: VitalKind.steps,
        value: value,
        measuredAt: at,
      )).id;
    }
    if (!ref.mounted) return;
    await _prefs.setString(
      rowKey,
      jsonEncode({
        'day': d.toJson()['day'],
        'id': id,
        'steps': d.steps,
        'at': now.toIso8601String(),
      }),
    );
    ref.invalidate(vitalsWeekProvider);
    ref.invalidate(vitalsWeekAllProvider);
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Map<String, dynamic>? _readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

final stepsProvider = NotifierProvider<StepsNotifier, StepsView>(
  StepsNotifier.new,
);
