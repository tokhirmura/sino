import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/l10n/app_lang.dart';
import 'models.dart';

/// Local notifications for reminders. Best effort: any platform failure
/// (no permission, plugin not set up, tests) is swallowed — reminders still
/// work in the app without notifications.
abstract class ReminderNotifications {
  /// Asks the OS for permission to show notifications. `false` if denied
  /// or unavailable.
  Future<bool> requestPermission();

  /// Replaces all scheduled reminder notifications with [reminders]
  /// (active ones only). [memberNames] — `family_members.id → name`.
  Future<void> sync(
    List<Reminder> reminders, {
    required AppLang lang,
    Map<String, String> memberNames = const {},
  });
}

/// Stable notification id of [reminderId] on [weekday] (0 = every day).
/// FNV-1a, kept below 2^31 for Android.
int reminderNotificationId(String reminderId, int weekday) {
  var h = 0x811c9dc5;
  for (final c in reminderId.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return (h % 200000000) * 10 + weekday;
}

/// Title and body of a reminder's notification.
(String, String) reminderNotificationText(
  Reminder r,
  AppLang lang, {
  String? memberName,
}) {
  final title = switch (lang) {
    AppLang.uz => 'Dori ichish vaqti',
    AppLang.ru => 'Время принять лекарство',
    AppLang.en => 'Time to take your medicine',
  };
  final dose = r.dose?.trim();
  final who = memberName == null ? '' : ' · $memberName';
  final body = '${r.name}${dose == null || dose.isEmpty ? '' : ' — $dose'}$who';
  return (title, body);
}

class LocalReminderNotifications implements ReminderNotifications {
  LocalReminderNotifications([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Payload prefix of our notifications — sync cancels only these.
  static const payloadPrefix = 'reminder:';
  static const channelId = 'sino_reminders';

  Future<bool>? _ready;

  Future<bool> _init() => _ready ??= () async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(_deviceLocation());
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
      debugPrint('Reminder notifications unavailable: $e');
      return false;
    }
  }();

  /// No timezone-name package in the app: take Asia/Tashkent when the
  /// device offset matches it (the target market), else any zone with the
  /// device's current offset.
  static tz.Location _deviceLocation() {
    final offset = DateTime.now().timeZoneOffset;
    final tashkent = tz.getLocation('Asia/Tashkent');
    if (tashkent.currentTimeZone.offset == offset) return tashkent;
    for (final l in tz.timeZoneDatabase.locations.values) {
      if (l.currentTimeZone.offset == offset) return l;
    }
    return tz.UTC;
  }

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
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return false;
    } catch (e) {
      debugPrint('Notification permission failed: $e');
      return false;
    }
  }

  @override
  Future<void> sync(
    List<Reminder> reminders, {
    required AppLang lang,
    Map<String, String> memberNames = const {},
  }) async {
    if (!await _init()) return;
    try {
      for (final p in await _plugin.pendingNotificationRequests()) {
        if (p.payload?.startsWith(payloadPrefix) ?? false) {
          await _plugin.cancel(id: p.id);
        }
      }
      for (final r in reminders) {
        if (!r.active || r.days.isEmpty) continue;
        final (title, body) = reminderNotificationText(
          r,
          lang,
          memberName: r.memberId == null ? null : memberNames[r.memberId],
        );
        if (r.everyDay) {
          await _schedule(r, 0, title, body, DateTimeComponents.time);
        } else {
          for (final d in r.days) {
            await _schedule(
              r,
              d,
              title,
              body,
              DateTimeComponents.dayOfWeekAndTime,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Reminder notifications sync failed: $e');
    }
  }

  Future<void> _schedule(
    Reminder r,
    int weekday,
    String title,
    String body,
    DateTimeComponents repeat,
  ) => _plugin.zonedSchedule(
    id: reminderNotificationId(r.id, weekday),
    scheduledDate: _next(r.hour, r.minute, weekday),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Dori eslatmalari',
        channelDescription: 'Dori ichish vaqti haqida eslatmalar',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    // Inexact: no SCHEDULE_EXACT_ALARM permission needed; a few minutes of
    // drift is fine for medication reminders.
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    title: title,
    body: body,
    payload: '$payloadPrefix${r.id}',
    matchDateTimeComponents: repeat,
  );

  /// Next [hour]:[minute] (on [weekday], 1–7; 0 = any day) after now.
  static tz.TZDateTime _next(int hour, int minute, int weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (!t.isAfter(now) || (weekday != 0 && t.weekday != weekday)) {
      t = tz.TZDateTime(tz.local, t.year, t.month, t.day + 1, hour, minute);
    }
    return t;
  }
}

/// Does nothing (web, tests).
class NoopReminderNotifications implements ReminderNotifications {
  const NoopReminderNotifications();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> sync(
    List<Reminder> reminders, {
    required AppLang lang,
    Map<String, String> memberNames = const {},
  }) async {}
}

final reminderNotificationsProvider = Provider<ReminderNotifications>(
  (ref) =>
      kIsWeb ? const NoopReminderNotifications() : LocalReminderNotifications(),
);
