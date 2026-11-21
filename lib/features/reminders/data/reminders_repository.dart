import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';
import '../../../core/storage/prefs.dart';
import 'models.dart';

/// Medication reminders and the intake history.
abstract class RemindersRepository {
  /// The user's reminders (incl. family members' and paused ones), by time.
  Future<List<Reminder>> reminders();

  /// Saves a new reminder ([draft]'s `id` / `createdAt` are ignored).
  Future<Reminder> add(Reminder draft);

  Future<Reminder> update(Reminder reminder);

  /// Deletes the reminder and its logs (`on delete cascade`).
  Future<void> remove(String id);

  /// Intake logs with `taken_at >= from`, oldest first.
  Future<List<ReminderLog>> logsSince(DateTime from);

  Future<ReminderLog> logTaken(String reminderId, DateTime at);

  /// Undo of [logTaken].
  Future<void> removeLog(String id);
}

const _timeout = Duration(seconds: 10);

int _byTime(Reminder a, Reminder b) {
  final c = a.minuteOfDay.compareTo(b.minuteOfDay);
  return c != 0 ? c : a.name.compareTo(b.name);
}

class SupabaseRemindersRepository implements RemindersRepository {
  SupabaseRemindersRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  @override
  Future<List<Reminder>> reminders() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('reminders')
        .select()
        .eq('user_id', uid)
        .timeout(_timeout);
    return [for (final r in rows) Reminder.fromJson(r)]..sort(_byTime);
  }

  @override
  Future<Reminder> add(Reminder draft) async {
    final row = await _client
        .from('reminders')
        .insert({...draft.toRow(), 'user_id': _uid})
        .select()
        .single()
        .timeout(_timeout);
    return Reminder.fromJson(row);
  }

  @override
  Future<Reminder> update(Reminder reminder) async {
    final row = await _client
        .from('reminders')
        .update(reminder.toRow())
        .eq('id', reminder.id)
        .select()
        .single()
        .timeout(_timeout);
    return Reminder.fromJson(row);
  }

  @override
  Future<void> remove(String id) =>
      _client.from('reminders').delete().eq('id', id).timeout(_timeout);

  @override
  Future<List<ReminderLog>> logsSince(DateTime from) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('reminder_logs')
        .select()
        .eq('user_id', uid)
        .gte('taken_at', from.toUtc().toIso8601String())
        .order('taken_at')
        .timeout(_timeout);
    return [for (final r in rows) ReminderLog.fromJson(r)];
  }

  @override
  Future<ReminderLog> logTaken(String reminderId, DateTime at) async {
    final row = await _client
        .from('reminder_logs')
        .insert({
          'reminder_id': reminderId,
          'user_id': _uid,
          'taken_at': at.toUtc().toIso8601String(),
        })
        .select()
        .single()
        .timeout(_timeout);
    return ReminderLog.fromJson(row);
  }

  @override
  Future<void> removeLog(String id) =>
      _client.from('reminder_logs').delete().eq('id', id).timeout(_timeout);
}

/// Offline: reminders and logs in SharedPreferences; on first use — the demo
/// from `assets/pharmacy/fake_pharmacy.json` (log dates relative to today).
class FakeRemindersRepository implements RemindersRepository {
  FakeRemindersRepository(this._prefs, {AssetBundle? bundle, this.now})
    : _bundle = bundle ?? rootBundle;

  final SharedPreferences _prefs;
  final AssetBundle _bundle;

  /// Fixed "now" for tests; `null` = real clock.
  final DateTime? now;

  static const demoAsset = 'assets/pharmacy/fake_pharmacy.json';
  static const remindersKey = 'reminders.fake_list';
  static const logsKey = 'reminders.fake_logs';

  DateTime get _now => now ?? DateTime.now();

  String _newId(String kind) =>
      'fake-$kind-${DateTime.now().microsecondsSinceEpoch}';

  Future<void>? _seeding;

  /// Fills both stores with the demo (once, when neither exists).
  /// Memoized: on first launch `reminders()` and `logsSince()` run at the
  /// same time — without it one could see the reminders key already
  /// written while the logs key is not yet, and read `null`.
  Future<void> _seed() {
    final pending = _seeding;
    if (pending != null) return pending;
    if (_prefs.containsKey(remindersKey) || _prefs.containsKey(logsKey)) {
      return Future.value();
    }
    return _seeding ??= _writeDemo().catchError((Object e, StackTrace st) {
      _seeding = null; // let the next read retry
      Error.throwWithStackTrace(e, st);
    });
  }

  Future<void> _writeDemo() async {
    final demo = jsonDecode(
      await _bundle.loadString(demoAsset, cache: false),
    ) as Map<String, dynamic>;
    final today = DateTime(_now.year, _now.month, _now.day);
    final created = today.subtract(const Duration(days: 30));
    final reminders = <Reminder>[];
    for (final r in demo['reminders'] as List) {
      final m = r as Map<String, dynamic>;
      final parts = (m['time'] as String).split(':');
      reminders.add(
        Reminder(
          id: 'fake-rem-${m['key']}',
          memberId: m['member'] as String?,
          name: m['name'] as String,
          dose: m['dose'] as String?,
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
          days: Reminder.normalizeDays([
            for (final d in m['days'] as List) d as int,
          ]),
          active: m['active'] as bool? ?? true,
          createdAt: created,
        ),
      );
    }
    final logs = <ReminderLog>[];
    var i = 0;
    for (final r in demo['reminder_logs'] as List) {
      final m = r as Map<String, dynamic>;
      final parts = (m['time'] as String).split(':');
      final day = today.subtract(Duration(days: m['days_ago'] as int));
      logs.add(
        ReminderLog(
          id: 'fake-log-${i++}',
          reminderId: 'fake-rem-${m['reminder']}',
          takenAt: DateTime(
            day.year,
            day.month,
            day.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          ),
        ),
      );
    }
    await _saveLogs(logs);
    await _saveReminders(reminders);
  }

  List<Map<String, dynamic>> _read(String key) => [
    for (final m in jsonDecode(_prefs.getString(key) ?? '[]') as List)
      Map<String, dynamic>.from(m as Map),
  ];

  Future<List<Reminder>> _allReminders() async {
    await _seed();
    return [for (final m in _read(remindersKey)) Reminder.fromJson(m)];
  }

  Future<List<ReminderLog>> _allLogs() async {
    await _seed();
    return [for (final m in _read(logsKey)) ReminderLog.fromJson(m)];
  }

  Future<void> _saveReminders(List<Reminder> list) => _prefs.setString(
    remindersKey,
    jsonEncode([for (final r in list) r.toJson()]),
  );

  Future<void> _saveLogs(List<ReminderLog> list) =>
      _prefs.setString(logsKey, jsonEncode([for (final l in list) l.toJson()]));

  @override
  Future<List<Reminder>> reminders() async =>
      (await _allReminders())..sort(_byTime);

  @override
  Future<Reminder> add(Reminder draft) async {
    final list = await _allReminders();
    final saved = draft.copyWith(id: _newId('rem'), createdAt: _now);
    await _saveReminders([...list, saved]);
    return saved;
  }

  @override
  Future<Reminder> update(Reminder reminder) async {
    final list = await _allReminders();
    final i = list.indexWhere((r) => r.id == reminder.id);
    if (i < 0) throw StateError('Reminder not found');
    final saved = reminder.copyWith(createdAt: list[i].createdAt);
    list[i] = saved;
    await _saveReminders(list);
    return saved;
  }

  @override
  Future<void> remove(String id) async {
    final list = await _allReminders();
    final logs = await _allLogs();
    await _saveReminders([
      for (final r in list)
        if (r.id != id) r,
    ]);
    await _saveLogs([
      for (final l in logs)
        if (l.reminderId != id) l,
    ]);
  }

  @override
  Future<List<ReminderLog>> logsSince(DateTime from) async => [
    for (final l in await _allLogs())
      if (!l.takenAt.isBefore(from)) l,
  ]..sort((a, b) => a.takenAt.compareTo(b.takenAt));

  @override
  Future<ReminderLog> logTaken(String reminderId, DateTime at) async {
    final logs = await _allLogs();
    final log = ReminderLog(
      id: _newId('log'),
      reminderId: reminderId,
      takenAt: at,
    );
    await _saveLogs([...logs, log]);
    return log;
  }

  @override
  Future<void> removeLog(String id) async {
    final logs = await _allLogs();
    await _saveLogs([
      for (final l in logs)
        if (l.id != id) l,
    ]);
  }
}

final remindersRepositoryProvider = Provider<RemindersRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeRemindersRepository(ref.watch(sharedPreferencesProvider))
      : SupabaseRemindersRepository(ref.watch(supabaseClientProvider)),
);
