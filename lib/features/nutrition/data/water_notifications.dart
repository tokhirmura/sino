import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily «drink water» notifications (Sprint 2.0, S2-7). Best effort: any
/// platform failure (no permission, tests) is swallowed.
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
  LocalWaterNotifications([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Module C notification ids start at 2 100 000 000 — far from the
  /// reminders' FNV ids (< 2 000 000 000); water is `baseId + hour`.
  static const baseId = 2100000100;
  static const payload = 'wellness:water';
  static const channelId = 'sino_wellness';

  Future<bool>? _ready;

  Future<bool> _init() => _ready ??= () async {
    try {
      tzdata.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (_) {
        // Keep the zone set elsewhere (or UTC).
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Water notifications unavailable: $e');
      return false;
    }
  }();

  @override
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } catch (e) {
      debugPrint('Notification permission failed: $e');
      return false;
    }
  }

  @override
  Future<void> scheduleDaily(
    List<int> hours, {
    required String title,
    required String body,
  }) async {
    if (!await _init()) return;
    try {
      await _cancelAll();
      final now = tz.TZDateTime.now(tz.local);
      for (final h in hours) {
        var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, h);
        if (!at.isAfter(now)) {
          at = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, h);
        }
        await _plugin.zonedSchedule(
          id: baseId + h,
          scheduledDate: at,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              'Sog‘lom turmush',
              channelDescription: 'Havo sifati va suv ichish eslatmalari',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          // Inexact: no exact-alarm permission; a few minutes are fine.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: title,
          body: body,
          payload: payload,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (e) {
      debugPrint('Water notifications failed: $e');
    }
  }

  @override
  Future<void> cancel() async {
    if (!await _init()) return;
    try {
      await _cancelAll();
    } catch (e) {
      debugPrint('Water notifications cancel failed: $e');
    }
  }

  /// Every hour of the day: the schedule may have changed between versions.
  Future<void> _cancelAll() async {
    for (var h = 0; h < 24; h++) {
      await _plugin.cancel(id: baseId + h);
    }
  }
}

/// Does nothing (web, desktop, tests).
class NoopWaterNotifications implements WaterNotifications {
  const NoopWaterNotifications();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleDaily(
    List<int> hours, {
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel() async {}
}

final waterNotificationsProvider = Provider<WaterNotifications>(
  (ref) => !kIsWeb && (Platform.isAndroid || Platform.isIOS)
      ? LocalWaterNotifications()
      : const NoopWaterNotifications(),
);
