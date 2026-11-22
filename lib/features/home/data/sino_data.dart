import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';

/// Raw rows the Sino index is built from. Read straight from the tables
/// (select only, own rows) — no other feature's code is imported.
///
/// Dates are local. `food_logs.date` / `water_logs.date` are `yyyy-MM-dd`
/// keys; timestamps (`taken_at`, `finished_at`, `measured_at`) are UTC in
/// the database and converted to local time here.
class SinoRaw {
  const SinoRaw({
    this.food = const [],
    this.water = const [],
    this.reminders = const [],
    this.doseLogs = const [],
    this.sessions = const [],
    this.vitals = const [],
  });

  final List<FoodRow> food;
  final List<WaterRow> water;
  final List<ReminderRow> reminders;
  final List<DoseLogRow> doseLogs;
  final List<DateTime> sessions;
  final List<VitalRow> vitals;
}

/// One `food_logs` row: kcal = servings × `foods.kcal` (or
/// `custom_food.kcal` for homemade / barcode / photo entries).
class FoodRow {
  const FoodRow(this.date, this.kcal);
  final DateTime date;
  final double kcal;
}

class WaterRow {
  const WaterRow(this.date, this.glasses);
  final DateTime date;
  final int glasses;
}

/// `reminders` row. [minutes] — time of day in minutes; [days] 1 = Mon … 7.
class ReminderRow {
  const ReminderRow({
    required this.id,
    required this.minutes,
    this.days = const [1, 2, 3, 4, 5, 6, 7],
    this.active = true,
    this.memberId,
    this.since,
  });

  final String id;
  final int minutes;
  final List<int> days;
  final bool active;

  /// Set for a family member's medicine — not counted in the user's index.
  final String? memberId;

  /// Local day the reminder was created (`created_at`); doses before it
  /// don't exist. `null` — always existed.
  final DateTime? since;
}

class DoseLogRow {
  const DoseLogRow(this.reminderId, this.takenAt);
  final String reminderId;
  final DateTime takenAt;
}

/// `vitals` row of kind `steps` or `sleep`.
class VitalRow {
  const VitalRow(this.kind, this.value, this.measuredAt);
  final String kind;
  final double value;
  final DateTime measuredAt;
}

/// `2026-11-21`.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `08:30:00` → 510.
int minutesOf(String time) {
  final p = time.split(':');
  return int.parse(p[0]) * 60 + (p.length > 1 ? int.parse(p[1]) : 0);
}

abstract class SinoDataRepository {
  /// All rows for the local days [from]..[to] (inclusive).
  Future<SinoRaw> load({required DateTime from, required DateTime to});

  /// Has the user ever reserved a medicine (`reservations`, own rows)?
  /// For the «Birinchi bron» badge.
  Future<bool> hasReservation();
}

class SupabaseSinoDataRepository implements SinoDataRepository {
  SupabaseSinoDataRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SinoRaw> load({required DateTime from, required DateTime to}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const SinoRaw();
    final start = dateOnly(from), end = dateOnly(to);
    final fromKey = dayKey(start), toKey = dayKey(end);
    final fromTs = start.toUtc().toIso8601String();
    final toTs = end.add(const Duration(days: 1)).toUtc().toIso8601String();

    final rows = await Future.wait<List<Map<String, dynamic>>>([
      _client
          .from('food_logs')
          .select('date, servings, foods(kcal), custom_food')
          .eq('user_id', uid)
          .gte('date', fromKey)
          .lte('date', toKey),
      _client
          .from('water_logs')
          .select('date, glasses')
          .eq('user_id', uid)
          .gte('date', fromKey)
          .lte('date', toKey),
      _client
          .from('reminders')
          .select('id, member_id, time, days, active, created_at')
          .eq('user_id', uid),
      _client
          .from('reminder_logs')
          .select('reminder_id, taken_at')
          .eq('user_id', uid)
          .gte('taken_at', fromTs)
          .lt('taken_at', toTs),
      _client
          .from('workout_sessions')
          .select('finished_at')
          .eq('user_id', uid)
          .gte('finished_at', fromTs)
          .lt('finished_at', toTs),
      _client
          .from('vitals')
          .select('kind, value, measured_at')
          .eq('user_id', uid)
          .inFilter('kind', ['steps', 'sleep'])
          .gte('measured_at', fromTs)
          .lt('measured_at', toTs),
    ]);
    return parseSinoRows(
      food: rows[0],
      water: rows[1],
      reminders: rows[2],
      doseLogs: rows[3],
      sessions: rows[4],
      vitals: rows[5],
    );
  }

  @override
  Future<bool> hasReservation() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final rows = await _client
        .from('reservations')
        .select('id')
        .eq('user_id', uid)
        .limit(1);
    return rows.isNotEmpty;
  }
}

/// Maps PostgREST rows to [SinoRaw] (separate for tests).
SinoRaw parseSinoRows({
  required List<Map<String, dynamic>> food,
  required List<Map<String, dynamic>> water,
  required List<Map<String, dynamic>> reminders,
  required List<Map<String, dynamic>> doseLogs,
  required List<Map<String, dynamic>> sessions,
  required List<Map<String, dynamic>> vitals,
}) {
  DateTime local(Object? v) => DateTime.parse(v as String).toLocal();
  double num0(Object? v) => (v as num?)?.toDouble() ?? 0;
  return SinoRaw(
    food: [
      for (final m in food)
        FoodRow(
          DateTime.parse(m['date'] as String),
          num0(m['servings']) *
              num0(
                ((m['foods'] ?? m['custom_food'])
                    as Map<String, dynamic>?)?['kcal'],
              ),
        ),
    ],
    water: [
      for (final m in water)
        WaterRow(
          DateTime.parse(m['date'] as String),
          (m['glasses'] as num?)?.toInt() ?? 0,
        ),
    ],
    reminders: [
      for (final m in reminders)
        ReminderRow(
          id: m['id'] as String,
          minutes: minutesOf(m['time'] as String),
          days: [
            for (final d in (m['days'] as List?) ?? const [1, 2, 3, 4, 5, 6, 7])
              (d as num).toInt(),
          ],
          active: m['active'] as bool? ?? true,
          memberId: m['member_id'] as String?,
          since: m['created_at'] == null
              ? null
              : dateOnly(local(m['created_at'])),
        ),
    ],
    doseLogs: [
      for (final m in doseLogs)
        DoseLogRow(m['reminder_id'] as String, local(m['taken_at'])),
    ],
    sessions: [for (final m in sessions) local(m['finished_at'])],
    vitals: [
      for (final m in vitals)
        VitalRow(
          m['kind'] as String,
          num0(m['value']),
          local(m['measured_at']),
        ),
    ],
  );
}

/// Plausible week of «Aziz» from `assets/core/sino_week.json`, laid out
/// relative to today. Today's doses after the current time stay untaken,
/// today's food, water and steps grow with the time of day.
class FakeSinoDataRepository implements SinoDataRepository {
  FakeSinoDataRepository({DateTime Function()? clock, AssetBundle? bundle})
    : _clock = clock ?? DateTime.now,
      _bundle = bundle ?? rootBundle;

  final DateTime Function() _clock;
  final AssetBundle _bundle;

  @override
  Future<SinoRaw> load({required DateTime from, required DateTime to}) async {
    final json = jsonDecode(
      await _bundle.loadString('assets/core/sino_week.json', cache: false),
    ) as Map<String, dynamic>;
    return buildFakeSinoRaw(json, now: _clock(), from: from, to: to);
  }

  /// `reservations` in the JSON (Aziz hasn't reserved anything yet).
  @override
  Future<bool> hasReservation() async {
    final json = jsonDecode(
      await _bundle.loadString('assets/core/sino_week.json', cache: false),
    ) as Map<String, dynamic>;
    return ((json['reservations'] as num?) ?? 0) > 0;
  }
}

/// Builds rows from the fake week JSON (separate for tests).
SinoRaw buildFakeSinoRaw(
  Map<String, dynamic> json, {
  required DateTime now,
  required DateTime from,
  required DateTime to,
}) {
  final today = dateOnly(now);
  final start = dateOnly(from), end = dateOnly(to);
  final reminders = [
    for (final r in json['reminders'] as List)
      ReminderRow(
        id: r['id'] as String,
        minutes: minutesOf(r['time'] as String),
        days: [for (final d in r['days'] as List) (d as num).toInt()],
        // Aziz set up his medicines at the start of the fake week.
        since: today.subtract(
          Duration(days: (r['since_days_ago'] as num?)?.toInt() ?? 6),
        ),
      ),
  ];
  final byId = {for (final r in reminders) r.id: r};

  final food = <FoodRow>[];
  final water = <WaterRow>[];
  final logs = <DoseLogRow>[];
  final sessions = <DateTime>[];
  final vitals = <VitalRow>[];

  // Today grows during the day: by ~17:30 the JSON values are reached.
  final hours = now.hour + now.minute / 60;
  final todayShare = (((hours - 7) / 14).clamp(0.25, 1.0) / 0.75).clamp(
    0.3,
    1.0,
  );

  DateTime at(DateTime day, int minutes) => day.add(Duration(minutes: minutes));
  bool past(DateTime t) => !t.isAfter(now);

  for (final d in json['days'] as List) {
    final day = today.subtract(Duration(days: (d['days_ago'] as num).toInt()));
    if (day.isBefore(start) || day.isAfter(end)) continue;
    final k = day == today ? todayShare : 1.0;
    if (d['kcal'] != null) {
      food.add(FoodRow(day, ((d['kcal'] as num) * k).roundToDouble()));
    }
    if (d['glasses'] != null) {
      water.add(WaterRow(day, ((d['glasses'] as num) * k).round()));
    }
    for (final id in (d['taken'] as List?) ?? const []) {
      final r = byId[id];
      if (r == null) continue;
      final t = at(day, r.minutes + 10);
      if (past(t)) logs.add(DoseLogRow(r.id, t));
    }
    for (var i = 0; i < ((d['workouts'] as num?) ?? 0); i++) {
      final t = at(day, 18 * 60 + 30 + i * 60);
      if (past(t)) sessions.add(t);
    }
    if (d['sleep'] != null) {
      vitals.add(VitalRow('sleep', (d['sleep'] as num) * 1.0, at(day, 7 * 60)));
    }
    if (d['steps'] != null) {
      final t = at(day, 21 * 60);
      vitals.add(
        VitalRow(
          'steps',
          ((d['steps'] as num) * k).roundToDouble(),
          past(t) ? t : now,
        ),
      );
    }
  }
  return SinoRaw(
    food: food,
    water: water,
    reminders: reminders,
    doseLogs: logs,
    sessions: sessions,
    vitals: vitals,
  );
}

final sinoDataRepositoryProvider = Provider<SinoDataRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeSinoDataRepository()
      : SupabaseSinoDataRepository(ref.watch(supabaseClientProvider)),
);
