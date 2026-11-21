import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

export 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show DateTimeComponents, PendingNotificationRequest;

/// Notification id ranges per module. Android ids are signed 32-bit ints,
/// so everything must stay ≤ [max].
abstract final class NotificationIds {
  /// Module B (reminders): `[0, remindersEnd)`.
  static const remindersEnd = 2000000000;

  /// Module C (wellness): `[wellnessBase, coreBase)`.
  static const wellnessBase = 2100000000;

  /// Module A (core / lead features): `[coreBase, max]`.
  static const coreBase = 2140000000;

  /// Largest id Android accepts (2^31 − 1).
  static const max = 2147483647;
}

/// Payload prefixes per module — [AppNotifications.cancelByPayloadPrefix]
/// removes only a module's own notifications.
abstract final class NotificationPayloads {
  static const reminder = 'reminder:';
  static const wellness = 'wellness:';
  static const core = 'core:';
}

/// An Android notification channel (ignored on iOS).
class AppNotificationChannel {
  const AppNotificationChannel({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;

  static const reminders = AppNotificationChannel(
    id: 'sino_reminders',
    name: 'Dori eslatmalari',
    description: 'Dori ichish vaqti haqida eslatmalar',
  );

  static const wellness = AppNotificationChannel(
    id: 'sino_wellness',
    name: 'Sog‘lom turmush',
    description: 'Havo sifati va suv ichish eslatmalari',
  );

  static const core = AppNotificationChannel(
    id: 'sino_core',
    name: 'Sino',
    description: 'Sino xabarlari',
  );
}

/// Shared local notifications. Best effort: every platform failure (no
/// permission, plugin not set up, web, desktop, tests) is swallowed and
/// logged with `debugPrint` — the app works without notifications.
abstract class AppNotifications {
  /// Time zones + plugin setup. Runs once; later calls return the cached
  /// result. `false` if notifications are unavailable. Other methods call
  /// it themselves.
  Future<bool> init();

  /// Asks the OS for permission (Android 13+, iOS). `false` if denied or
  /// unavailable.
  Future<bool> requestPermission();

  /// Schedules notification [id] at [at] (a `tz.TZDateTime` is used as is,
  /// a plain `DateTime` is the same instant in `tz.local`). [repeat] makes
  /// it recurring (`DateTimeComponents.time` — daily,
  /// `dayOfWeekAndTime` — weekly). Inexact on Android: no exact-alarm
  /// permission, a few minutes of drift.
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    required AppNotificationChannel channel,
    DateTimeComponents? repeat,
  });

  /// Removes notification [id].
  Future<void> cancel(int id);

  /// Scheduled notifications of the whole app (empty if unavailable).
  Future<List<PendingNotificationRequest>> pendingNotificationRequests();

  /// Removes every scheduled notification whose payload starts with
  /// [prefix] (see [NotificationPayloads]).
  Future<void> cancelByPayloadPrefix(String prefix);
}

/// The next [hour]:[minute] in `tz.local` after [from] (default: now), on
/// [weekday] (1 = Mon … 7 = Sun; 0 = any day). Call after
/// [AppNotifications.init] so `tz.local` is the device zone.
tz.TZDateTime nextLocalTime(
  int hour,
  int minute, {
  int weekday = 0,
  tz.TZDateTime? from,
}) {
  final now = from ?? tz.TZDateTime.now(tz.local);
  final loc = now.location;
  var t = tz.TZDateTime(loc, now.year, now.month, now.day, hour, minute);
  while (!t.isAfter(now) || (weekday != 0 && t.weekday != weekday)) {
    t = tz.TZDateTime(loc, t.year, t.month, t.day + 1, hour, minute);
  }
  return t;
}

class LocalAppNotifications implements AppNotifications {
  LocalAppNotifications({
    FlutterLocalNotificationsPlugin? plugin,
    this.zoneName,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// IANA zone name source; `null` — `flutter_timezone` (tests pass a fake).
  @visibleForTesting
  final Future<String> Function()? zoneName;

  Future<bool>? _ready;

  @override
  Future<bool> init() => _ready ??= _init();

  Future<bool> _init() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(await deviceLocation(zoneName: zoneName));
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
      debugPrint('Notifications unavailable: $e');
      return false;
    }
  }

  /// The device's IANA zone from `flutter_timezone`. If the platform call
  /// fails or the name is unknown to the tz database (old aliases), falls
  /// back to a zone with the device's current UTC offset, then UTC.
  @visibleForTesting
  static Future<tz.Location> deviceLocation({
    Future<String> Function()? zoneName,
    Duration? offset,
  }) async {
    try {
      final name = await (zoneName ?? _platformZoneName)();
      return tz.getLocation(name);
    } catch (e) {
      debugPrint('Device timezone unavailable, using offset: $e');
    }
    final off = offset ?? DateTime.now().timeZoneOffset;
    for (final l in tz.timeZoneDatabase.locations.values) {
      if (l.currentTimeZone.offset == off) return l;
    }
    return tz.UTC;
  }

  static Future<String> _platformZoneName() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  @override
  Future<bool> requestPermission() async {
    if (!await init()) return false;
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
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    required AppNotificationChannel channel,
    DateTimeComponents? repeat,
  }) async {
    if (id < 0 || id > NotificationIds.max) {
      debugPrint('Notification id $id is outside 0…${NotificationIds.max}');
      return;
    }
    if (!await init()) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: at is tz.TZDateTime
            ? at
            : tz.TZDateTime.from(at, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        payload: payload,
        matchDateTimeComponents: repeat,
      );
    } catch (e) {
      debugPrint('Notification $id not scheduled: $e');
    }
  }

  @override
  Future<void> cancel(int id) async {
    if (!await init()) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Notification $id not cancelled: $e');
    }
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    if (!await init()) return const [];
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('Pending notifications unavailable: $e');
      return const [];
    }
  }

  @override
  Future<void> cancelByPayloadPrefix(String prefix) async {
    for (final p in await pendingNotificationRequests()) {
      if (p.payload?.startsWith(prefix) ?? false) await cancel(p.id);
    }
  }
}

/// Does nothing (web, desktop, tests).
class NoopAppNotifications implements AppNotifications {
  const NoopAppNotifications();

  @override
  Future<bool> init() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    required AppNotificationChannel channel,
    DateTimeComponents? repeat,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => const [];

  @override
  Future<void> cancelByPayloadPrefix(String prefix) async {}
}

/// One shared instance per app: [LocalAppNotifications] on Android and iOS,
/// [NoopAppNotifications] elsewhere (web, desktop, `flutter test`).
final appNotificationsProvider = Provider<AppNotifications>(
  (ref) => !kIsWeb && (Platform.isAndroid || Platform.isIOS)
      ? LocalAppNotifications()
      : const NoopAppNotifications(),
);
