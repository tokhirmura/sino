import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/core/backend/backend.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/features/reminders/application/reminder_schedule.dart';
import 'package:sino/features/reminders/application/reminders_providers.dart';
import 'package:sino/features/reminders/data/models.dart';
import 'package:sino/features/reminders/data/reminder_notifications.dart';
import 'package:sino/features/reminders/data/reminders_repository.dart';

/// Records every sync instead of touching the plugin.
class _RecordingNotifications implements ReminderNotifications {
  final syncs = <List<Reminder>>[];
  Map<String, String> lastNames = const {};

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> sync(
    List<Reminder> reminders, {
    required AppLang lang,
    Map<String, String> memberNames = const {},
  }) async {
    syncs.add(reminders);
    lastNames = memberNames;
  }
}

class _GatedRepo extends FakeRemindersRepository {
  _GatedRepo(super.prefs);

  Completer<void> gate = Completer<void>()..complete();
  bool fail = false;

  Future<void> _write() async {
    await gate.future;
    if (fail) throw Exception('network');
  }

  @override
  Future<Reminder> add(Reminder draft) async {
    await _write();
    return super.add(draft);
  }

  @override
  Future<Reminder> update(Reminder reminder) async {
    await _write();
    return super.update(reminder);
  }

  @override
  Future<ReminderLog> logTaken(String reminderId, DateTime at) async {
    await _write();
    return super.logTaken(reminderId, at);
  }
}

Reminder _r(
  String id, {
  int hour = 8,
  List<int> days = allWeekdays,
  bool active = true,
  DateTime? createdAt,
}) => Reminder(
  id: id,
  name: id,
  hour: hour,
  minute: 0,
  days: days,
  active: active,
  createdAt: createdAt,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('models', () {
    test('Reminder parses the time column and normalizes days', () {
      final r = Reminder.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'member_id': null,
        'name': 'Amlodipin',
        'dose': '5 mg',
        'time': '08:30:00',
        'days': [5, 1, 1, 9, 3],
        'active': true,
        'created_at': '2026-11-01T03:00:00+00:00',
      });
      expect((r.hour, r.minute), (8, 30));
      expect(r.days, [1, 3, 5]);
      expect(r.timeValue, '08:30:00');
      expect(r.toRow()['time'], '08:30:00');
      expect(r.toRow().containsKey('id'), isFalse);
      final back = Reminder.fromJson(r.toJson());
      expect(back.days, r.days);
      expect(back.createdAt, r.createdAt);
    });

    test('empty dose is stored as null', () {
      expect(_r('x').copyWith(dose: '  ').toRow()['dose'], isNull);
    });
  });

  group('schedule', () {
    // Tuesday.
    final day = DateTime(2026, 11, 17);
    final rs = [
      _r('evening', hour: 20),
      _r('morning', hour: 8),
      _r('weekend', days: [6, 7]),
      _r('paused', active: false),
    ];

    test('doses of a day: active, on the weekday, by time', () {
      final doses = dosesForDay(day, rs, const []);
      expect(doses.map((d) => d.reminder.id), ['morning', 'evening']);
      expect(doses.first.scheduledAt, DateTime(2026, 11, 17, 8));
    });

    test('a taken dose stays visible after the reminder is paused', () {
      final log = ReminderLog(
        id: 'l',
        reminderId: 'paused',
        takenAt: DateTime(2026, 11, 17, 8, 5),
      );
      final doses = dosesForDay(day, rs, [log]);
      expect(doses.map((d) => d.reminder.id), contains('paused'));
    });

    test('status: upcoming → due → missed; taken by the same-day log', () {
      final dose = dosesForDay(day, [_r('m')], const []).single;
      expect(dose.status(DateTime(2026, 11, 17, 7)), DoseStatus.upcoming);
      expect(dose.status(DateTime(2026, 11, 17, 9)), DoseStatus.due);
      expect(dose.status(DateTime(2026, 11, 17, 10, 1)), DoseStatus.missed);
      final logs = [
        ReminderLog(
          id: 'yesterday',
          reminderId: 'm',
          takenAt: DateTime(2026, 11, 16, 8),
        ),
      ];
      expect(dosesForDay(day, [_r('m')], logs).single.taken, isFalse);
      logs.add(
        ReminderLog(
          id: 't',
          reminderId: 'm',
          takenAt: DateTime(2026, 11, 17, 11),
        ),
      );
      expect(
        dosesForDay(day, [
          _r('m'),
        ], logs).single.status(DateTime(2026, 11, 17, 12)),
        DoseStatus.taken,
      );
    });

    test('next dose skips taken ones and looks into the next days', () {
      // 21:00 would still return the 20:00 dose (due within the grace).
      expect(
        nextDose(DateTime(2026, 11, 17, 21), rs, const [])!.reminder.id,
        'evening',
      );
      final now = DateTime(2026, 11, 17, 22, 30);
      final next = nextDose(now, rs, const []);
      expect(next!.reminder.id, 'morning');
      expect(next.scheduledAt, DateTime(2026, 11, 18, 8));
      expect(nextDose(now, const [], const []), isNull);
    });

    test('adherence counts finished doses since the reminder existed', () {
      final now = DateTime(2026, 11, 17, 9); // today’s 08:00 is still due
      final r = _r('m', createdAt: DateTime(2026, 11, 14, 12));
      // Expected: 15th, 16th (14th 08:00 was before creation).
      final logs = [
        ReminderLog(
          id: 'a',
          reminderId: 'm',
          takenAt: DateTime(2026, 11, 15, 8),
        ),
      ];
      final a = adherence(now, [r], logs);
      expect((a.taken, a.expected), (1, 2));
      expect(a.percent, 50);
      expect(adherence(now, const [], const []).ratio, isNull);
    });
  });

  group('notifications helpers', () {
    test('ids are stable, per weekday and fit in 31 bits', () {
      final a = reminderNotificationId('fake-rem-x', 3);
      expect(reminderNotificationId('fake-rem-x', 3), a);
      expect(reminderNotificationId('fake-rem-x', 4), a + 1);
      expect(reminderNotificationId('fake-rem-y', 3), isNot(a));
      expect(a, lessThan(1 << 31));
      expect(a % 10, 3);
    });

    test('text in the app language with dose and member', () {
      final r = _r('x').copyWith(name: 'Amlodipin', dose: '5 mg');
      final (title, body) = reminderNotificationText(
        r,
        AppLang.uz,
        memberName: 'Akbar',
      );
      expect(title, 'Dori ichish vaqti');
      expect(body, 'Amlodipin — 5 mg · Akbar');
      expect(reminderNotificationText(r, AppLang.ru).$1, contains('лекарство'));
    });
  });

  group('FakeRemindersRepository', () {
    late SharedPreferences prefs;
    final now = DateTime(2026, 11, 17, 12);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('demo: reminders by time, logs relative to today', () async {
      final repo = FakeRemindersRepository(prefs, now: now);
      final rs = await repo.reminders();
      expect(rs.map((r) => r.name).first, 'Omeprazol');
      expect(
        rs.firstWhere((r) => r.id == 'fake-rem-amlodipine').memberId,
        'fake-father',
      );
      final logs = await repo.logsSince(DateTime(2026, 11, 1));
      expect(logs, hasLength(10));
      expect(logs.last.takenAt.isBefore(DateTime(2026, 11, 17)), isTrue);
    });

    test('add / update / remove persist; remove drops the logs', () async {
      final repo = FakeRemindersRepository(prefs, now: now);
      final saved = await repo.add(_r('ignored').copyWith(name: 'Aspirin'));
      expect(saved.id, startsWith('fake-rem-'));
      expect(saved.createdAt, now);
      await repo.update(saved.copyWith(hour: 21));
      await repo.remove('fake-rem-amlodipine');

      final again = FakeRemindersRepository(prefs, now: now);
      final rs = await again.reminders();
      expect(rs.firstWhere((r) => r.id == saved.id).hour, 21);
      expect(rs.any((r) => r.id == 'fake-rem-amlodipine'), isFalse);
      final logs = await again.logsSince(DateTime(2026, 11, 1));
      expect(logs.any((l) => l.reminderId == 'fake-rem-amlodipine'), isFalse);
      expect(logs, hasLength(5));
    });
  });

  group('providers', () {
    late ProviderContainer container;
    late _GatedRepo repo;
    late _RecordingNotifications notifications;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = _GatedRepo(prefs);
      notifications = _RecordingNotifications();
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          useFakeProvider.overrideWithValue(true),
          remindersRepositoryProvider.overrideWithValue(repo),
          reminderNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);
      container.listen(remindersProvider, (_, _) {});
      container.listen(reminderLogsProvider, (_, _) {});
    });

    RemindersNotifier reminders() => container.read(remindersProvider.notifier);
    ReminderLogsNotifier logs() =>
        container.read(reminderLogsProvider.notifier);

    test('load syncs notifications with family member names', () async {
      await container.read(remindersProvider.future);
      await pumpEventQueue();
      expect(notifications.syncs, isNotEmpty);
      expect(notifications.syncs.last, hasLength(4));
      expect(notifications.lastNames['fake-father'], 'Akbar');
    });

    test('add: validation, optimistic row, then sync', () async {
      await container.read(remindersProvider.future);
      await expectLater(
        reminders().add(_r('x').copyWith(name: ' ')),
        throwsA(isA<ReminderException>()),
      );
      await expectLater(
        reminders().add(_r('x', days: const [])),
        throwsA(isA<ReminderException>()),
      );

      repo.gate = Completer<void>();
      final future = reminders().add(
        _r('x', hour: 6).copyWith(name: 'Aspirin'),
      );
      await Future<void>.delayed(Duration.zero);
      final list = container.read(remindersProvider).value!;
      expect(list.first.id, startsWith('pending-'));
      repo.gate.complete();
      final saved = await future;
      await pumpEventQueue();
      expect(container.read(remindersProvider).value!.first.id, saved.id);
      expect(notifications.syncs.last.map((r) => r.id), contains(saved.id));
      expect(
        notifications.syncs.last.any((r) => r.id.startsWith('pending-')),
        isFalse,
      );
    });

    test('pause rolls back on failure', () async {
      await container.read(remindersProvider.future);
      repo.fail = true;
      await expectLater(
        reminders().setActive('fake-rem-vitamin_d3', false),
        throwsException,
      );
      final r = container
          .read(remindersProvider)
          .value!
          .firstWhere((r) => r.id == 'fake-rem-vitamin_d3');
      expect(r.active, isTrue);
    });

    test('mark taken: once per day, undo, future days refused', () async {
      final rs = await container.read(remindersProvider.future);
      await container.read(reminderLogsProvider.future);
      final vit = rs.firstWhere((r) => r.id == 'fake-rem-vitamin_d3');
      final today = dayOf(DateTime.now());

      final log = await logs().markTaken(vit, today);
      final again = await logs().markTaken(vit, today);
      expect(again.id, log.id);
      final doses = container.read(dosesForDayProvider(today)).value!;
      expect(doses.firstWhere((d) => d.reminder.id == vit.id).taken, isTrue);

      await logs().undo(log.id);
      final after = container.read(dosesForDayProvider(today)).value!;
      expect(after.firstWhere((d) => d.reminder.id == vit.id).taken, isFalse);

      await expectLater(
        logs().markTaken(vit, today.add(const Duration(days: 1))),
        throwsA(isA<ReminderException>()),
      );
    });

    test('a past day’s dose is logged at its scheduled time', () async {
      final rs = await container.read(remindersProvider.future);
      await container.read(reminderLogsProvider.future);
      final vit = rs.firstWhere((r) => r.id == 'fake-rem-vitamin_d3');
      final threeDaysAgo = dayOf(DateTime.now())
          .subtract(const Duration(days: 3));
      final log = await logs().markTaken(vit, threeDaysAgo);
      expect(log.takenAt, vit.at(threeDaysAgo));
    });

    test('failed mark rolls back; history is newest first', () async {
      final rs = await container.read(remindersProvider.future);
      await container.read(reminderLogsProvider.future);
      repo.fail = true;
      await expectLater(
        logs().markTaken(rs.first, dayOf(DateTime.now())),
        throwsException,
      );
      final history = container.read(intakeHistoryProvider).value!;
      expect(history, hasLength(10));
      expect(
        history.first.log.takenAt.isAfter(history.last.log.takenAt),
        isTrue,
      );
      expect(history.first.reminder, isNotNull);
      expect(container.read(adherenceProvider).value!.expected, greaterThan(0));
    });

    test('remove drops the reminder and reloads the logs', () async {
      await container.read(remindersProvider.future);
      await container.read(reminderLogsProvider.future);
      final removed = await reminders().remove('fake-rem-amlodipine');
      expect(removed!.name, 'Amlodipin');
      final logsNow = await container.read(reminderLogsProvider.future);
      expect(
        logsNow.any((l) => l.reminderId == 'fake-rem-amlodipine'),
        isFalse,
      );
    });
  });
}
