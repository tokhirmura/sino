import 'package:flutter_test/flutter_test.dart';
import 'package:sino/core/notifications/local_notifications.dart';
import 'package:sino/features/nutrition/data/water_notifications.dart';
import 'package:sino/features/weather/data/air_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The shared service, recording calls.
class _Core implements AppNotifications {
  final scheduled =
      <
        ({
          int id,
          DateTime at,
          String payload,
          String channel,
          DateTimeComponents? repeat,
        })
      >[];
  final cancelled = <int>[];
  int asks = 0;

  @override
  Future<bool> init() async => true;

  @override
  Future<bool> requestPermission() async {
    asks++;
    return true;
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
    scheduled.add((
      id: id,
      at: at,
      payload: payload,
      channel: channel.id,
      repeat: repeat,
    ));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => const [];

  @override
  Future<void> cancelByPayloadPrefix(String prefix) async {}
}

void main() {
  // What the real `init` does: the device zone.
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tashkent'));
  });

  test('air: one wellness notification, replaced each time', () async {
    final core = _Core();
    final air = LocalAirNotifications(core);
    final at = DateTime(2026, 11, 23, 7, 30);
    await air.schedule(at: at, title: 't', body: 'b');
    expect(core.cancelled, [2100000001]);
    final s = core.scheduled.single;
    expect(s.id, 2100000001);
    expect(s.at, at);
    expect(s.payload, 'wellness:air');
    expect(s.channel, 'sino_wellness');
    expect(s.repeat, isNull);

    await air.cancel();
    expect(core.cancelled.last, 2100000001);
    expect(await air.requestPermission(), isTrue);
    expect(core.asks, 1);
  });

  test('water: daily at each hour, ids in the module C range', () async {
    final core = _Core();
    await LocalWaterNotifications(core)
        .scheduleDaily([9, 21], title: 't', body: 'b');
    // Old schedule removed first (every hour of the day).
    expect(core.cancelled, hasLength(24));
    expect([for (final s in core.scheduled) s.id], [2100000109, 2100000121]);
    expect([for (final s in core.scheduled) s.at.hour], [9, 21]);
    for (final s in core.scheduled) {
      expect(s.payload, 'wellness:water');
      expect(s.channel, 'sino_wellness');
      expect(s.repeat, DateTimeComponents.time);
      expect(s.id, greaterThanOrEqualTo(NotificationIds.wellnessBase));
      expect(s.id, lessThan(NotificationIds.coreBase));
    }
  });
}
