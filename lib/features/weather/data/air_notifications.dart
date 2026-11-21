import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/local_notifications.dart';

/// The morning «bad air» notification (Sprint 2.0, S2-7) on top of the
/// shared [AppNotifications] (which swallows platform failures).
abstract class AirNotifications {
  /// Asks the OS for permission to show notifications; `false` if denied.
  Future<bool> requestPermission();

  /// Replaces the scheduled morning notification with one at [at].
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  });

  /// Removes the scheduled morning notification, if any.
  Future<void> cancel();
}

class LocalAirNotifications implements AirNotifications {
  const LocalAirNotifications(this._n);

  final AppNotifications _n;

  /// Module C range ([NotificationIds.wellnessBase]); water uses +100….
  static const id = NotificationIds.wellnessBase + 1;
  static const payload = '${NotificationPayloads.wellness}air';

  @override
  Future<bool> requestPermission() => _n.requestPermission();

  @override
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await _n.cancel(id);
    await _n.schedule(
      id: id,
      at: at,
      title: title,
      body: body,
      payload: payload,
      channel: AppNotificationChannel.wellness,
    );
  }

  @override
  Future<void> cancel() => _n.cancel(id);
}

final airNotificationsProvider = Provider<AirNotifications>(
  (ref) => LocalAirNotifications(ref.watch(appNotificationsProvider)),
);
