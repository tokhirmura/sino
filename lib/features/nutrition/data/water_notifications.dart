import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/local_notifications.dart';

/// Daily «drink water» notifications (Sprint 2.0, S2-7) on top of the
/// shared [AppNotifications] (which swallows platform failures).
abstract class WaterNotifications {
  /// Asks the OS for permission to show notifications; `false` if denied.
  Future<bool> requestPermission();

  /// Replaces the water notifications with daily ones at [hours] (:00).
  Future<void> scheduleDaily(
    List<int> hours, {
    required String title,
    required String body,
  });

  /// Removes all water notifications.
  Future<void> cancel();
}

class LocalWaterNotifications implements WaterNotifications {
  const LocalWaterNotifications(this._n);

  final AppNotifications _n;

  /// Module C range ([NotificationIds.wellnessBase]): water is
  /// `baseId + hour` (the air alert is `wellnessBase + 1`).
  static const baseId = NotificationIds.wellnessBase + 100;
  static const payload = '${NotificationPayloads.wellness}water';

  @override
  Future<bool> requestPermission() => _n.requestPermission();

  @override
  Future<void> scheduleDaily(
    List<int> hours, {
    required String title,
    required String body,
  }) async {
    await cancel();
    // `nextLocalTime` needs the device zone set up by `init`.
    if (!await _n.init()) return;
    for (final h in hours) {
      await _n.schedule(
        id: baseId + h,
        at: nextLocalTime(h, 0),
        title: title,
        body: body,
        payload: payload,
        channel: AppNotificationChannel.wellness,
        repeat: DateTimeComponents.time,
      );
    }
  }

  /// Every hour of the day: the schedule may have changed between versions.
  @override
  Future<void> cancel() async {
    for (var h = 0; h < 24; h++) {
      await _n.cancel(baseId + h);
    }
  }
}

final waterNotificationsProvider = Provider<WaterNotifications>(
  (ref) => LocalWaterNotifications(ref.watch(appNotificationsProvider)),
);
