import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';

/// A family member's medicine reminder (`reminders` with `member_id`).
class CareReminder {
  const CareReminder({
    required this.id,
    required this.memberId,
    required this.name,
    required this.minutes,
    this.dose,
    this.days = const [1, 2, 3, 4, 5, 6, 7],
    this.active = true,
    this.since,
  });

  final String id;
  final String memberId;
  final String name;
  final String? dose;

  /// Time of day in minutes.
  final int minutes;

  /// 1 = Mon … 7 = Sun.
  final List<int> days;
  final bool active;

  /// Local day it was created; no doses before it. `null` — always.
  final DateTime? since;
}

/// «Taken» mark (`reminder_logs`).
class CareLog {
  const CareLog(this.reminderId, this.takenAt);
  final String reminderId;
  final DateTime takenAt;
}

/// Upcoming doctor visit (`appointments`, booked).
class CareVisit {
  const CareVisit({
    required this.memberId,
    required this.startsAt,
    required this.doctor,
    this.specialty,
    this.online = false,
  });

  final String memberId;
  final DateTime startsAt;
  final String doctor;
  final String? specialty;
  final bool online;
}

/// Active medicine reservation (`reservations`, pending / ready).
class CareReservation {
  const CareReservation({
    required this.memberId,
    required this.medicine,
    required this.status,
    this.pharmacy,
  });

  final String memberId;
  final String medicine;
  final String? pharmacy;

  /// `pending` | `ready`.
  final String status;

  bool get ready => status == 'ready';
}

/// Today's raw rows about the family (members come from core).
class FamilyCareRaw {
  const FamilyCareRaw({
    this.reminders = const [],
    this.logs = const [],
    this.visits = const [],
    this.reservations = const [],
  });

  final List<CareReminder> reminders;
  final List<CareLog> logs;
  final List<CareVisit> visits;
  final List<CareReservation> reservations;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _minutesOf(String time) {
  final p = time.split(':');
  return int.parse(p[0]) * 60 + (p.length > 1 ? int.parse(p[1]) : 0);
}

/// Reads the family part of other modules' tables — select only, own rows;
/// no other feature's code is imported.
abstract class FamilyCareRepository {
  /// Reminders of family members, today's logs, upcoming visits and active
  /// reservations. [now] — local.
  Future<FamilyCareRaw> load(DateTime now);
}

class SupabaseFamilyCareRepository implements FamilyCareRepository {
  SupabaseFamilyCareRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<FamilyCareRaw> load(DateTime now) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const FamilyCareRaw();
    final today = _dateOnly(now);
    final rows = await Future.wait<List<Map<String, dynamic>>>([
      _client
          .from('reminders')
          .select('id, member_id, name, dose, time, days, active, created_at')
          .eq('user_id', uid)
          .not('member_id', 'is', null),
      _client
          .from('reminder_logs')
          .select('reminder_id, taken_at')
          .eq('user_id', uid)
          .gte('taken_at', today.toUtc().toIso8601String())
          .lt(
            'taken_at',
            today.add(const Duration(days: 1)).toUtc().toIso8601String(),
          ),
      _client
          .from('appointments')
          .select('member_id, starts_at, online, doctors(name, specialty)')
          .eq('user_id', uid)
          .eq('status', 'booked')
          .not('member_id', 'is', null)
          .gte('starts_at', now.toUtc().toIso8601String())
          .order('starts_at'),
      _client
          .from('reservations')
          .select('for_member_id, status, medicines(name), pharmacies(name)')
          .eq('user_id', uid)
          .inFilter('status', ['pending', 'ready'])
          .not('for_member_id', 'is', null)
          .order('created_at', ascending: false),
    ]);
    return parseFamilyCareRows(
      reminders: rows[0],
      logs: rows[1],
      visits: rows[2],
      reservations: rows[3],
    );
  }
}

/// PostgREST rows → [FamilyCareRaw] (UTC → local). Separate for tests.
FamilyCareRaw parseFamilyCareRows({
  required List<Map<String, dynamic>> reminders,
  required List<Map<String, dynamic>> logs,
  required List<Map<String, dynamic>> visits,
  required List<Map<String, dynamic>> reservations,
}) {
  DateTime local(Object? v) => DateTime.parse(v as String).toLocal();
  String? embedded(Object? m, String key) =>
      (m as Map<String, dynamic>?)?[key] as String?;
  return FamilyCareRaw(
    reminders: [
      for (final m in reminders)
        CareReminder(
          id: m['id'] as String,
          memberId: m['member_id'] as String,
          name: m['name'] as String,
          dose: m['dose'] as String?,
          minutes: _minutesOf(m['time'] as String),
          days: [
            for (final d in (m['days'] as List?) ?? const [1, 2, 3, 4, 5, 6, 7])
              (d as num).toInt(),
          ],
          active: m['active'] as bool? ?? true,
          since: m['created_at'] == null
              ? null
              : _dateOnly(local(m['created_at'])),
        ),
    ],
    logs: [
      for (final m in logs)
        CareLog(m['reminder_id'] as String, local(m['taken_at'])),
    ],
    visits: [
      for (final m in visits)
        CareVisit(
          memberId: m['member_id'] as String,
          startsAt: local(m['starts_at']),
          doctor: embedded(m['doctors'], 'name') ?? '—',
          specialty: embedded(m['doctors'], 'specialty'),
          online: m['online'] as bool? ?? false,
        ),
    ],
    reservations: [
      for (final m in reservations)
        CareReservation(
          memberId: m['for_member_id'] as String,
          medicine: embedded(m['medicines'], 'name') ?? '—',
          pharmacy: embedded(m['pharmacies'], 'name'),
          status: m['status'] as String,
        ),
    ],
  );
}

/// Demo family day from `assets/core/family_care.json` (members are core
/// `FamilyMember.fakes`). Times are absolute (`"time": "08:00"`) or
/// relative to now (`"minutes_ago": 95`) so the missed dose shows up at any
/// hour of a demo.
class FakeFamilyCareRepository implements FamilyCareRepository {
  FakeFamilyCareRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  @override
  Future<FamilyCareRaw> load(DateTime now) async {
    final json = jsonDecode(
      await _bundle.loadString('assets/core/family_care.json', cache: false),
    ) as Map<String, dynamic>;
    return buildFakeFamilyCare(json, now);
  }
}

/// Builds rows from the fake JSON (separate for tests).
FamilyCareRaw buildFakeFamilyCare(Map<String, dynamic> json, DateTime now) {
  final today = _dateOnly(now);
  final nowMinutes = now.hour * 60 + now.minute;
  final reminders = <CareReminder>[];
  final logs = <CareLog>[];
  for (final r in json['reminders'] as List) {
    final m = r as Map<String, dynamic>;
    final minutes = m['time'] != null
        ? _minutesOf(m['time'] as String)
        // Relative: rounded down to 5 min, never before 00:05 today.
        : (((nowMinutes - (m['minutes_ago'] as num).toInt()) ~/ 5) * 5).clamp(
            5,
            24 * 60 - 1,
          );
    final reminder = CareReminder(
      id: m['id'] as String,
      memberId: m['member'] as String,
      name: m['name'] as String,
      dose: m['dose'] as String?,
      minutes: minutes,
    );
    reminders.add(reminder);
    final takenAt = today.add(Duration(minutes: minutes + 5));
    if (m['taken'] == true && !takenAt.isAfter(now)) {
      logs.add(CareLog(reminder.id, takenAt));
    }
  }
  return FamilyCareRaw(
    reminders: reminders,
    logs: logs,
    visits: [
      for (final v in (json['visits'] as List? ?? const []))
        CareVisit(
          memberId: v['member'] as String,
          startsAt: today
              .add(Duration(days: (v['days_from_now'] as num).toInt()))
              .add(Duration(minutes: _minutesOf(v['time'] as String))),
          doctor: v['doctor'] as String,
          specialty: v['specialty'] as String?,
          online: v['online'] as bool? ?? false,
        ),
    ],
    reservations: [
      for (final r in (json['reservations'] as List? ?? const []))
        CareReservation(
          memberId: r['member'] as String,
          medicine: r['medicine'] as String,
          pharmacy: r['pharmacy'] as String?,
          status: r['status'] as String,
        ),
    ],
  );
}

final familyCareRepositoryProvider = Provider<FamilyCareRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeFamilyCareRepository()
      : SupabaseFamilyCareRepository(ref.watch(supabaseClientProvider)),
);
