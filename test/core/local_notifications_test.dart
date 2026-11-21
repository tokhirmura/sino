import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/core/notifications/local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Records plugin calls; no platform channels.
class _FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  _FakePlugin({this.failInit = false});

  final bool failInit;
  int initCalls = 0;
  final scheduled =
      <
        ({
          int id,
          tz.TZDateTime at,
          String? payload,
          DateTimeComponents? repeat,
          String? channel,
        })
      >[];
  final cancelled = <int>[];
  List<PendingNotificationRequest> pending = const [];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initCalls++;
    if (failInit) throw Exception('no plugin');
    return true;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled.add((
      id: id,
      at: scheduledDate,
      payload: payload,
      repeat: matchDateTimeComponents,
      channel: notificationDetails.android?.channelId,
    ));
  }

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      cancelled.add(id);

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => pending;
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('provider picks Noop outside Android/iOS (flutter test)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(appNotificationsProvider);
    expect(n, isA<NoopAppNotifications>());
    expect(await n.init(), isFalse);
    expect(await n.requestPermission(), isFalse);
    expect(await n.pendingNotificationRequests(), isEmpty);
  });

  test('init runs once, sets the device zone', () async {
    final plugin = _FakePlugin();
    final n = LocalAppNotifications(
      plugin: plugin,
      zoneName: () async => 'Asia/Tashkent',
    );
    final results = await Future.wait([n.init(), n.init(), n.init()]);
    await n.init();
    await n.cancel(5);
    expect(results, everyElement(isTrue));
    expect(plugin.initCalls, 1);
    expect(tz.local.name, 'Asia/Tashkent');
  });

  test('failed init is swallowed and cached; nothing is scheduled', () async {
    final plugin = _FakePlugin(failInit: true);
    final n = LocalAppNotifications(
      plugin: plugin,
      zoneName: () async => 'Asia/Tashkent',
    );
    expect(await n.init(), isFalse);
    await n.schedule(
      id: NotificationIds.wellnessBase,
      at: DateTime.now().add(const Duration(hours: 1)),
      title: 't',
      body: 'b',
      payload: '${NotificationPayloads.wellness}air',
      channel: AppNotificationChannel.wellness,
    );
    expect(await n.requestPermission(), isFalse);
    expect(plugin.initCalls, 1);
    expect(plugin.scheduled, isEmpty);
  });

  test('schedule passes id, instant, payload, channel and repeat', () async {
    final plugin = _FakePlugin();
    final n = LocalAppNotifications(
      plugin: plugin,
      zoneName: () async => 'Asia/Tashkent',
    );
    final at = DateTime.utc(2026, 11, 22, 3);
    await n.schedule(
      id: NotificationIds.wellnessBase + 8,
      at: at,
      title: 'Suv',
      body: 'Bir stakan suv iching',
      payload: '${NotificationPayloads.wellness}water',
      channel: AppNotificationChannel.wellness,
      repeat: DateTimeComponents.time,
    );
    // Out of the Android int range: refused without a platform call.
    await n.schedule(
      id: NotificationIds.max + 1,
      at: at,
      title: 'x',
      body: 'x',
      payload: NotificationPayloads.core,
      channel: AppNotificationChannel.core,
    );
    expect(plugin.scheduled, hasLength(1));
    final s = plugin.scheduled.single;
    expect(s.id, 2100000008);
    expect(s.at.isAtSameMomentAs(at), isTrue);
    expect(s.at.location.name, 'Asia/Tashkent');
    expect(s.at.hour, 8);
    expect(s.payload, 'wellness:water');
    expect(s.channel, 'sino_wellness');
    expect(s.repeat, DateTimeComponents.time);
  });

  test('cancelByPayloadPrefix removes only that module', () async {
    final plugin = _FakePlugin()
      ..pending = const [
        PendingNotificationRequest(1, 'a', 'b', 'reminder:r1'),
        PendingNotificationRequest(2, 'a', 'b', 'reminder:r2'),
        PendingNotificationRequest(2100000001, 'a', 'b', 'wellness:air'),
        PendingNotificationRequest(7, 'a', 'b', null),
      ];
    final n = LocalAppNotifications(
      plugin: plugin,
      zoneName: () async => 'Asia/Tashkent',
    );
    await n.cancelByPayloadPrefix(NotificationPayloads.reminder);
    expect(plugin.cancelled, [1, 2]);
  });

  test('deviceLocation falls back to the UTC offset, then UTC', () async {
    final byOffset = await LocalAppNotifications.deviceLocation(
      zoneName: () async => 'Mars/Olympus',
      offset: const Duration(hours: 5),
    );
    expect(byOffset.currentTimeZone.offset, const Duration(hours: 5));
    final utc = await LocalAppNotifications.deviceLocation(
      zoneName: () async => throw Exception('no channel'),
      offset: const Duration(hours: 5, minutes: 17),
    );
    expect(utc, tz.UTC);
  });

  test('nextLocalTime: today, tomorrow, weekday', () {
    final loc = tz.getLocation('Asia/Tashkent');
    // Saturday 2026-11-21 14:30.
    final from = tz.TZDateTime(loc, 2026, 11, 21, 14, 30);
    expect(
      nextLocalTime(20, 0, from: from),
      tz.TZDateTime(loc, 2026, 11, 21, 20),
    );
    expect(
      nextLocalTime(8, 0, from: from),
      tz.TZDateTime(loc, 2026, 11, 22, 8),
    );
    expect(
      nextLocalTime(14, 30, from: from),
      tz.TZDateTime(loc, 2026, 11, 22, 14, 30),
    );
    final monday = nextLocalTime(9, 0, weekday: 1, from: from);
    expect(monday, tz.TZDateTime(loc, 2026, 11, 23, 9));
    expect(monday.weekday, DateTime.monday);
  });

  test('id ranges fit Android int32 and do not overlap', () {
    expect(
      NotificationIds.remindersEnd,
      lessThan(NotificationIds.wellnessBase),
    );
    expect(NotificationIds.wellnessBase, lessThan(NotificationIds.coreBase));
    expect(NotificationIds.coreBase, lessThan(NotificationIds.max));
    expect(NotificationIds.max, (1 << 31) - 1);
  });
}
