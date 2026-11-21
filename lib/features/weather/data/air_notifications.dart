import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The morning «bad air» notification (Sprint 2.0, S2-7). Best effort: any
/// platform failure (no permission, tests) is swallowed.
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
  LocalAirNotifications([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Module C notification ids start at 2 100 000 000 — far from the
  /// reminders' FNV ids (< 2 000 000 000).
  static const id = 2100000001;
  static const payload = 'wellness:air';
  static const channelId = 'sino_wellness';

  Future<bool>? _ready;

  Future<bool> _init() => _ready ??= () async {
    try {
      tzdata.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (_) {
        // Unknown zone name: scheduling below uses absolute instants.
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
      debugPrint('Air notifications unavailable: $e');
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
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  }) async {
    if (!await _init()) return;
    try {
      await _plugin.cancel(id: id);
      await _plugin.zonedSchedule(
        id: id,
        // The same instant whatever tz.local is.
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Sog‘lom turmush',
            channelDescription: 'Havo sifati va suv ichish eslatmalari',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // Inexact: no exact-alarm permission; a few minutes are fine.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Air notification failed: $e');
    }
  }

  @override
  Future<void> cancel() async {
    if (!await _init()) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Air notification cancel failed: $e');
    }
  }
}

/// Does nothing (web, desktop, tests).
class NoopAirNotifications implements AirNotifications {
  const NoopAirNotifications();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel() async {}
}

final airNotificationsProvider = Provider<AirNotifications>(
  (ref) => !kIsWeb && (Platform.isAndroid || Platform.isIOS)
      ? LocalAirNotifications()
      : const NoopAirNotifications(),
);
