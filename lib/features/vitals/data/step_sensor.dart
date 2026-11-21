import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';

/// The phone's step counter (S2-3). The same in fake and Supabase modes:
/// it is hardware, not backend data.
abstract class StepSensor {
  /// Cumulative steps since the phone booted. Errors with
  /// [StepSensorUnavailable] when there is no sensor (emulator).
  ///
  /// Without the «physical activity» permission Android simply sends
  /// nothing — the caller treats a long silence as «maybe no permission».
  Stream<int> counts();

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

/// `pedometer` plugin. iOS shows its own Motion prompt on the first
/// listen (`NSMotionUsageDescription`). Android 10+ needs the runtime
/// `ACTIVITY_RECOGNITION` permission, which can't be requested from Dart
/// without `permission_handler` (not in pubspec yet) — the screen sends the
/// user to the app settings instead.
class PedometerStepSensor implements StepSensor {
  @override
  Stream<int> counts() => Pedometer.stepCountStream
      .map((e) => e.steps)
      .handleError(
        (Object e) => throw StepSensorUnavailable(e),
        test: (e) => e is! StepSensorUnavailable,
      );

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}

/// Test double: push counts with [emit], errors with [fail].
class FakeStepSensor implements StepSensor {
  final _c = StreamController<int>.broadcast();
  int listens = 0;
  int settingsOpened = 0;

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
