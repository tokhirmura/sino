import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';

/// What the seeding did.
class SeedResult {
  const SeedResult({
    required this.familyMembers,
    required this.medicalRecords,
    required this.labResults,
    this.familyCare = 0,
    this.skipped = false,
  });

  const SeedResult.skipped()
    : familyMembers = 0,
      medicalRecords = 0,
      labResults = 0,
      familyCare = 0,
      skipped = true;

  final int familyMembers;
  final int medicalRecords;
  final int labResults;

  /// Family members' medicine reminders added for the «Oila» demo.
  final int familyCare;

  /// The user already had data — nothing was added.
  final bool skipped;
}

/// Demo data for the jury: family, medical record, lab results for the
/// current user, from `assets/core/sample_profile_data.json`; plus the
/// «Oila» demo — the mother's two medicines (one missed), the father's
/// doctor visit, the mother's ready reservation.
abstract class SampleDataRepository {
  Future<SeedResult> seed();
}

const _asset = 'assets/core/sample_profile_data.json';

Future<Map<String, dynamic>> _loadSample(AssetBundle bundle) async =>
    jsonDecode(await bundle.loadString(_asset, cache: false))
        as Map<String, dynamic>;

List<Map<String, dynamic>> _list(Map<String, dynamic> json, String key) => [
  for (final e in json[key] as List) Map<String, dynamic>.from(e as Map),
];

class SupabaseSampleDataRepository implements SampleDataRepository {
  SupabaseSampleDataRepository(this._client, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final SupabaseClient _client;
  final AssetBundle _bundle;

  @override
  Future<SeedResult> seed() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');

    final json = await _loadSample(_bundle);
    final now = DateTime.now();

    // Never duplicate or overwrite: profile data only into an empty account,
    // the family demo only while the family has no reminders.
    final existing = await Future.wait([
      _client.from('family_members').select('id').eq('user_id', uid).limit(1),
      _client.from('medical_records').select('id').eq('user_id', uid).limit(1),
      _client.from('lab_results').select('id').eq('user_id', uid).limit(1),
    ]);
    final base = existing.any((rows) => rows.isNotEmpty)
        ? const SeedResult.skipped()
        : await _seedProfile(uid, json, now);
    final care = await _seedFamilyCare(uid, json, now);
    if (base.skipped && care == 0) return const SeedResult.skipped();
    return SeedResult(
      familyMembers: base.familyMembers,
      medicalRecords: base.medicalRecords,
      labResults: base.labResults,
      familyCare: care,
    );
  }

  Future<SeedResult> _seedProfile(
    String uid,
    Map<String, dynamic> json,
    DateTime now,
  ) async {
    final day = DateFormat('yyyy-MM-dd');

    final family = _list(json, 'family_members');
    final inserted = await _client
        .from('family_members')
        .insert([
          for (final m in family)
            {
              'user_id': uid,
              'name': m['name'],
              'relation': m['relation'],
              'birth_year': now.year - (m['age'] as int),
              'blood_type': m['blood_type'],
              'allergies': m['allergies'],
              'phone': m['phone'],
            },
        ])
        .select('id, name');
    final memberIds = {
      for (final r in inserted) r['name'] as String: r['id'] as String,
    };

    final records = _list(json, 'medical_records');
    await _client.from('medical_records').insert([
      for (final r in records)
        {
          'user_id': uid,
          'member_id': memberIds[r['member']],
          'date': day.format(
            now.subtract(Duration(days: r['days_ago'] as int)),
          ),
          'kind': r['kind'],
          'title': r['title'],
          'institution': r['institution'],
          'source': r['source'],
          'notes': r['notes'],
        },
    ]);

    final labs = _list(json, 'lab_results');
    await _client.from('lab_results').insert([
      for (final l in labs)
        {
          'user_id': uid,
          'name': l['name'],
          'value': l['value'],
          'unit': l['unit'],
          'ref_low': l['ref_low'],
          'ref_high': l['ref_high'],
          'taken_at': now
              .subtract(Duration(days: l['days_ago'] as int))
              .toUtc()
              .toIso8601String(),
        },
    ]);

    return SeedResult(
      familyMembers: family.length,
      medicalRecords: records.length,
      labResults: labs.length,
    );
  }

  /// «Oila» demo; 0 when there is no family or it already has reminders.
  Future<int> _seedFamilyCare(
    String uid,
    Map<String, dynamic> json,
    DateTime now,
  ) async {
    final care = json['family_care'] as Map<String, dynamic>?;
    if (care == null) return 0;
    final checks = await Future.wait([
      _client
          .from('family_members')
          .select('id, relation')
          .eq('user_id', uid)
          .order('created_at'),
      _client
          .from('reminders')
          .select('id')
          .eq('user_id', uid)
          .not('member_id', 'is', null)
          .limit(1),
    ]);
    final members = checks[0];
    if (members.isEmpty || checks[1].isNotEmpty) return 0;
    String? memberFor(Object? relation) {
      for (final m in members) {
        if (m['relation'] == relation) return m['id'] as String;
      }
      return null;
    }

    final today = DateTime(now.year, now.month, now.day);
    final plans = [
      for (final r in _list(care, 'reminders'))
        (
          row: r,
          member: memberFor(r['relation']) ?? members.first['id'] as String,
          minutes: demoMinutes(now, (r['minutes_ago'] as num).toInt()),
        ),
    ];
    final inserted = await _client
        .from('reminders')
        .insert([
          for (final p in plans)
            {
              'user_id': uid,
              'member_id': p.member,
              'name': p.row['name'],
              'dose': p.row['dose'],
              'time': hhmmss(p.minutes),
              'days': const [1, 2, 3, 4, 5, 6, 7],
              'active': true,
            },
        ])
        .select('id');
    final logs = <Map<String, dynamic>>[];
    for (var i = 0; i < plans.length && i < inserted.length; i++) {
      final at = today.add(Duration(minutes: plans[i].minutes + 5));
      if (plans[i].row['taken'] == true && !at.isAfter(now)) {
        logs.add({
          'user_id': uid,
          'reminder_id': inserted[i]['id'],
          'taken_at': at.toUtc().toIso8601String(),
        });
      }
    }
    if (logs.isNotEmpty) await _client.from('reminder_logs').insert(logs);

    // A doctor visit and a reservation from the catalogs, if they exist.
    final catalogs = await Future.wait([
      _client.from('doctors').select('id').limit(1),
      _client
          .from('pharmacy_stock')
          .select('medicine_id, pharmacy_id')
          .limit(1),
    ]);
    final visit = care['visit'] as Map<String, dynamic>?;
    final visitMember = memberFor(visit?['relation']);
    if (visit != null && visitMember != null && catalogs[0].isNotEmpty) {
      final t = (visit['time'] as String).split(':');
      await _client.from('appointments').insert({
        'user_id': uid,
        'doctor_id': catalogs[0].first['id'],
        'member_id': visitMember,
        'starts_at': today
            .add(Duration(days: (visit['days_from_now'] as num).toInt()))
            .add(Duration(hours: int.parse(t[0]), minutes: int.parse(t[1])))
            .toUtc()
            .toIso8601String(),
        'online': visit['online'] ?? false,
        'status': 'booked',
      });
    }
    final reservation = care['reservation'] as Map<String, dynamic>?;
    final resMember = memberFor(reservation?['relation']);
    if (reservation != null && resMember != null && catalogs[1].isNotEmpty) {
      await _client.from('reservations').insert({
        'user_id': uid,
        'medicine_id': catalogs[1].first['medicine_id'],
        'pharmacy_id': catalogs[1].first['pharmacy_id'],
        'for_member_id': resMember,
        'status': reservation['status'] ?? 'pending',
      });
    }
    return inserted.length;
  }
}

/// Demo time «[minutesAgo] ago» as minutes of today: rounded down to 5 min,
/// never before 00:05 (so the dose stays today).
int demoMinutes(DateTime now, int minutesAgo) =>
    (((now.hour * 60 + now.minute - minutesAgo) ~/ 5) * 5).clamp(
      5,
      24 * 60 - 1,
    );

/// 545 → «09:05:00».
String hhmmss(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}:00';

/// Fake mode already shows sample data; just validate the asset.
class FakeSampleDataRepository implements SampleDataRepository {
  FakeSampleDataRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  @override
  Future<SeedResult> seed() async {
    final json = await _loadSample(_bundle);
    return SeedResult(
      familyMembers: _list(json, 'family_members').length,
      medicalRecords: _list(json, 'medical_records').length,
      labResults: _list(json, 'lab_results').length,
      familyCare: _list(
        json['family_care'] as Map<String, dynamic>,
        'reminders',
      ).length,
    );
  }
}

final sampleDataRepositoryProvider = Provider<SampleDataRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeSampleDataRepository()
      : SupabaseSampleDataRepository(ref.watch(supabaseClientProvider)),
);
