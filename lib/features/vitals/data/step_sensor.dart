import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// The «physical activity» (Android) / «Motion & Fitness» (iOS)
/// permission the step counter needs.
enum StepPermission {
  granted,

  /// Not given yet or denied once: can be asked again.
  denied,

  /// Denied for good (or restricted): only the system settings help.
  blocked,
}

/// The phone's step counter (S2-3). The same in fake and Supabase modes:
/// it is hardware, not backend data.
abstract class StepSensor {
  /// Cumulative steps since the phone booted. Errors with
  /// [StepSensorUnavailable] when there is no sensor (emulator).
  ///
  /// Without the permission Android simply sends nothing — check
  /// [permission] first; a long silence is still possible.
  Stream<int> counts();

  /// The permission state; with [request] — shows the system prompt when it
  /// can still be asked (no prompt if already granted or blocked).
  Future<StepPermission> permission({bool request = false});

  /// Opens the app's system settings (to allow «physical activity»).
  Future<void> openSettings();
}

/// No step counter on this device (or no plugin, e.g. in tests).
class StepSensorUnavailable implements Exception {
  const StepSensorUnavailable([this.cause]);

  final Object? cause;

  @override
  String toString() => 'StepSensorUnavailable($cause)';
}

/// `pedometer` plugin; the permission through `permission_handler`:
/// Android 10+ — runtime `ACTIVITY_RECOGNITION` (older ones grant it at
/// install), iOS — Motion (`NSMotionUsageDescription`).
class PedometerStepSensor implements StepSensor {
  @override
  Stream<int> counts() => Pedometer.stepCountStream
      .map((e) => e.steps)
      .handleError(
        (Object e) => throw StepSensorUnavailable(e),
        test: (e) => e is! StepSensorUnavailable,
      );

  @override
  Future<StepPermission> permission({bool request = false}) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return StepPermission.granted;
    }
    final p = Platform.isIOS
        ? Permission.sensors
        : Permission.activityRecognition;
    try {
      final s = request ? await p.request() : await p.status;
      if (s.isGranted || s.isLimited) return StepPermission.granted;
      if (s.isPermanentlyDenied || s.isRestricted) {
        return StepPermission.blocked;
      }
      return StepPermission.denied;
    } catch (e) {
      // No plugin: let the sensor itself decide (silence / error).
      debugPrint('Step permission unavailable: $e');
      return StepPermission.granted;
    }
  }

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}

/// Test double: push counts with [emit], errors with [fail].
class FakeStepSensor implements StepSensor {
  FakeStepSensor({this.perm = StepPermission.granted});

  final _c = StreamController<int>.broadcast();
  int listens = 0;
  int settingsOpened = 0;

  /// Current permission; a request turns it into [answer].
  StepPermission perm;
  StepPermission answer = StepPermission.granted;
  int requests = 0;

  @override
  Future<StepPermission> permission({bool request = false}) async {
    if (request) {
      requests++;
      if (perm == StepPermission.denied) perm = answer;
    }
    return perm;
  }

  void emit(int count) => _c.add(count);

  void fail(Object e) => _c.addError(e);

  @override
  Stream<int> counts() {
    listens++;
    return _c.stream;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

final stepSensorProvider = Provider<StepSensor>((ref) => PedometerStepSensor());
