import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';
import '../../../core/storage/prefs.dart';
import 'models.dart';

/// Doctors catalog and the user's appointments.
abstract class DoctorsRepository {
  /// Whole `doctors` catalog, best rated first.
  Future<List<Doctor>> doctors();

  /// The user's appointments (all statuses) with `doctor` joined, by time.
  Future<List<Appointment>> appointments();

  Future<Appointment> book({
    required String doctorId,
    required DateTime startsAt,
    String? memberId,
    bool online = false,
  });

  Future<void> cancel(String id);
}

/// Filter of the catalog: [specialty] slug, free-text [query] over the
/// name, clinic and specialty slug (apostrophes ignored), [onlineOnly].
/// Keeps the input order.
List<Doctor> filterDoctors(
  List<Doctor> doctors, {
  String? specialty,
  String query = '',
  bool onlineOnly = false,
}) {
  final q = normalizeDoctorText(query);
  return [
    for (final d in doctors)
      if ((specialty == null || d.specialty == specialty) &&
          (!onlineOnly || d.online) &&
          (q.isEmpty ||
              [
                d.name,
                d.clinic ?? '',
                d.specialty,
              ].any((s) => normalizeDoctorText(s).contains(q))))
        d,
  ];
}

String normalizeDoctorText(String s) =>
    s.toLowerCase().replaceAll(RegExp('[\'‘’ʻʼ`´]'), '').trim();

const _timeout = Duration(seconds: 10);

int _byRating(Doctor a, Doctor b) {
  final c = (b.rating ?? 0).compareTo(a.rating ?? 0);
  return c != 0 ? c : a.name.compareTo(b.name);
}

int _byTime(Appointment a, Appointment b) => a.startsAt.compareTo(b.startsAt);

class SupabaseDoctorsRepository implements DoctorsRepository {
  SupabaseDoctorsRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  @override
  Future<List<Doctor>> doctors() async {
    final rows = await _client.from('doctors').select().timeout(_timeout);
    return [for (final r in rows) Doctor.fromJson(r)]..sort(_byRating);
  }

  @override
  Future<List<Appointment>> appointments() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('appointments')
        .select('*, doctors(*)')
        .eq('user_id', uid)
        .order('starts_at')
        .timeout(_timeout);
    return [for (final r in rows) Appointment.fromJson(r)];
  }

  @override
  Future<Appointment> book({
    required String doctorId,
    required DateTime startsAt,
    String? memberId,
    bool online = false,
  }) async {
    final row = await _client
        .from('appointments')
        .insert({
          'user_id': _uid,
          'doctor_id': doctorId,
          'member_id': memberId,
          'starts_at': startsAt.toUtc().toIso8601String(),
          'online': online,
        })
        .select('*, doctors(*)')
        .single()
        .timeout(_timeout);
    return Appointment.fromJson(row);
  }

  @override
  Future<void> cancel(String id) => _client
      .from('appointments')
      .update({'status': AppointmentStatus.cancelled.name})
      .eq('id', id)
      .timeout(_timeout);
}

/// Offline: catalog from `assets/pharmacy/doctors.json`, appointments in
/// SharedPreferences (first use — demo from `fake_pharmacy.json`, dates
/// relative to today).
class FakeDoctorsRepository implements DoctorsRepository {
  FakeDoctorsRepository(
    this._prefs, {
    AssetBundle? bundle,
    this.now,
    DateTime Function()? clock,
  }) : _bundle = bundle ?? rootBundle,
       _clock = clock ?? DateTime.now;

  final SharedPreferences _prefs;
  final AssetBundle _bundle;

  /// Fixed "now" for tests; `null` = real clock.
  final DateTime? now;

  final DateTime Function() _clock;

  static const doctorsAsset = 'assets/pharmacy/doctors.json';
  static const demoAsset = 'assets/pharmacy/fake_pharmacy.json';
  static const appointmentsKey = 'doctors.fake_appointments';

  DateTime get _now => now ?? _clock();

  List<Doctor>? _doctors;

  // cache: false — a cached asset future never completes in the next
  // widget test (each test has its own fake async zone).
  Future<String> _load(String asset) => _bundle.loadString(asset, cache: false);

  @override
  Future<List<Doctor>> doctors() async => _doctors ??= [
    for (final r in jsonDecode(await _load(doctorsAsset)) as List)
      Doctor.fromJson(r as Map<String, dynamic>),
  ]..sort(_byRating);

  Future<List<Appointment>> _all() async {
    final raw = _prefs.getString(appointmentsKey);
    final List<Appointment> list;
    if (raw != null) {
      list = [
        for (final m in jsonDecode(raw) as List)
          Appointment.fromJson(Map<String, dynamic>.from(m as Map)),
      ];
    } else {
      final bySlug = {for (final d in await doctors()) d.slug: d};
      final demo = jsonDecode(await _load(demoAsset)) as Map<String, dynamic>;
      final today = DateTime(_now.year, _now.month, _now.day);
      list = [];
      var i = 0;
      for (final r in demo['appointments'] as List) {
        final m = r as Map<String, dynamic>;
        final doc = bySlug[m['doctor']];
        if (doc == null) continue;
        final parts = (m['time'] as String).split(':');
        final day = DateTime(
          today.year,
          today.month,
          today.day + (m['days_from_now'] as int),
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        list.add(
          Appointment(
            id: 'fake-appt-${i++}',
            doctorId: doc.id,
            memberId: m['member'] as String?,
            startsAt: day,
            online: m['online'] as bool? ?? false,
            status: AppointmentStatus.fromName(m['status'] as String?),
            createdAt: _now,
          ),
        );
      }
      await _save(list);
    }
    final byId = {for (final d in await doctors()) d.id: d};
    return [for (final a in list) a.copyWith(doctor: byId[a.doctorId])]
      ..sort(_byTime);
  }

  Future<void> _save(List<Appointment> list) => _prefs.setString(
    appointmentsKey,
    jsonEncode([for (final a in list) a.toJson()]),
  );

  @override
  Future<List<Appointment>> appointments() => _all();

  @override
  Future<Appointment> book({
    required String doctorId,
    required DateTime startsAt,
    String? memberId,
    bool online = false,
  }) async {
    final list = await _all();
    final byId = {for (final d in await doctors()) d.id: d};
    final a = Appointment(
      id: 'fake-appt-${DateTime.now().microsecondsSinceEpoch}',
      doctorId: doctorId,
      memberId: memberId,
      startsAt: startsAt,
      online: online,
      createdAt: _now,
      doctor: byId[doctorId],
    );
    await _save([...list, a]);
    return a;
  }

  @override
  Future<void> cancel(String id) async {
    final list = await _all();
    await _save([
      for (final a in list)
        a.id == id ? a.copyWith(status: AppointmentStatus.cancelled) : a,
    ]);
  }
}

/// The feature's clock: slots, «today», upcoming / past. Tests override it
/// with a fixed time so results don't depend on when they run.
final doctorsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final doctorsRepositoryProvider = Provider<DoctorsRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeDoctorsRepository(
          ref.watch(sharedPreferencesProvider),
          clock: ref.watch(doctorsClockProvider),
        )
      : SupabaseDoctorsRepository(ref.watch(supabaseClientProvider)),
);
