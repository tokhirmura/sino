import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';
import '../../../core/data/user.dart';

/// Where a record came from: state (`davlat`) or private (`xususiy`) clinic.
enum RecordSource {
  davlat,
  xususiy;

  static RecordSource fromName(String? s) =>
      s == 'xususiy' ? RecordSource.xususiy : RecordSource.davlat;
}

/// A row of `medical_records`. [memberId] `null` = the user themself.
class MedicalRecord {
  const MedicalRecord({
    required this.id,
    required this.date,
    required this.kind,
    required this.title,
    required this.source,
    this.memberId,
    this.institution,
    this.notes,
  });

  final String id;
  final String? memberId;
  final DateTime date;

  /// visit | lab | prescription | vaccine | diagnosis | … (free text in DB).
  final String kind;
  final String title;
  final String? institution;
  final RecordSource source;
  final String? notes;

  factory MedicalRecord.fromMap(Map<String, dynamic> m) => MedicalRecord(
    id: m['id'] as String,
    memberId: m['member_id'] as String?,
    date: DateTime.parse(m['date'] as String),
    kind: m['kind'] as String,
    title: m['title'] as String,
    institution: m['institution'] as String?,
    source: RecordSource.fromName(m['source'] as String?),
    notes: m['notes'] as String?,
  );
}

enum LabStatus { low, normal, high }

/// A row of `lab_results`.
class LabResult {
  const LabResult({
    required this.id,
    required this.name,
    required this.value,
    required this.takenAt,
    this.unit,
    this.refLow,
    this.refHigh,
  });

  final String id;
  final String name;
  final double value;
  final String? unit;
  final double? refLow;
  final double? refHigh;
  final DateTime takenAt;

  LabStatus get status {
    if (refLow != null && value < refLow!) return LabStatus.low;
    if (refHigh != null && value > refHigh!) return LabStatus.high;
    return LabStatus.normal;
  }

  factory LabResult.fromMap(Map<String, dynamic> m) => LabResult(
    id: m['id'] as String,
    name: m['name'] as String,
    value: (m['value'] as num).toDouble(),
    unit: m['unit'] as String?,
    refLow: (m['ref_low'] as num?)?.toDouble(),
    refHigh: (m['ref_high'] as num?)?.toDouble(),
    takenAt: DateTime.parse(m['taken_at'] as String).toLocal(),
  );
}

/// Electronic medical record of the current user (and their family).
abstract class MedicalRepository {
  /// Newest first.
  Future<List<MedicalRecord>> records();

  /// Newest first.
  Future<List<LabResult>> labs();
}

class SupabaseMedicalRepository implements MedicalRepository {
  SupabaseMedicalRepository(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Future<List<MedicalRecord>> records() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _client
        .from('medical_records')
        .select()
        .eq('user_id', uid)
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return [for (final r in rows) MedicalRecord.fromMap(r)];
  }

  @override
  Future<List<LabResult>> labs() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _client
        .from('lab_results')
        .select()
        .eq('user_id', uid)
        .order('taken_at', ascending: false);
    return [for (final r in rows) LabResult.fromMap(r)];
  }
}

/// Offline: the same demo data the dev-mode seeding writes to Supabase
/// (`assets/core/sample_profile_data.json`), dates relative to today.
class FakeMedicalRepository implements MedicalRepository {
  FakeMedicalRepository({required this.family, AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  /// Current fake family — records of «Dilfuza» get her member id.
  final List<FamilyMember> family;
  final AssetBundle _bundle;

  static const asset = 'assets/core/sample_profile_data.json';

  // cache: false — a cached asset future never completes in the next
  // widget test (each test has its own fake async zone).
  Future<Map<String, dynamic>> _json() async =>
      jsonDecode(await _bundle.loadString(asset, cache: false))
          as Map<String, dynamic>;

  static DateTime _daysAgo(Object? days) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - (days as int));
  }

  @override
  Future<List<MedicalRecord>> records() async {
    final ids = {for (final m in family) m.name: m.id};
    final json = await _json();
    final list = <MedicalRecord>[];
    var i = 0;
    for (final r in json['medical_records'] as List) {
      final m = r as Map<String, dynamic>;
      final member = m['member'] as String?;
      // Record of a member that was deleted in fake mode — skip it.
      if (member != null && !ids.containsKey(member)) continue;
      list.add(
        MedicalRecord(
          id: 'fake-record-${i++}',
          memberId: member == null ? null : ids[member],
          date: _daysAgo(m['days_ago']),
          kind: m['kind'] as String,
          title: m['title'] as String,
          institution: m['institution'] as String?,
          source: RecordSource.fromName(m['source'] as String?),
          notes: m['notes'] as String?,
        ),
      );
    }
    return list..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<List<LabResult>> labs() async {
    final json = await _json();
    var i = 0;
    return [
      for (final l in json['lab_results'] as List)
        LabResult(
          id: 'fake-lab-${i++}',
          name: l['name'] as String,
          value: (l['value'] as num).toDouble(),
          unit: l['unit'] as String?,
          refLow: (l['ref_low'] as num?)?.toDouble(),
          refHigh: (l['ref_high'] as num?)?.toDouble(),
          takenAt: _daysAgo(l['days_ago']),
        ),
    ]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
  }
}

final medicalRepositoryProvider = Provider<MedicalRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeMedicalRepository(family: ref.watch(fakeFamilyProvider))
      : SupabaseMedicalRepository(ref.watch(supabaseClientProvider)),
);

final medicalRecordsProvider = FutureProvider<List<MedicalRecord>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(medicalRepositoryProvider).records();
});

final labResultsProvider = FutureProvider<List<LabResult>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(medicalRepositoryProvider).labs();
});
