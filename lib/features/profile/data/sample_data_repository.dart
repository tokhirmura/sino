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
    this.skipped = false,
  });

  const SeedResult.skipped()
    : familyMembers = 0,
      medicalRecords = 0,
      labResults = 0,
      skipped = true;

  final int familyMembers;
  final int medicalRecords;
  final int labResults;

  /// The user already had data — nothing was added.
  final bool skipped;
}

/// Demo data for the jury: family, medical record, lab results for the
/// current user, from `assets/core/sample_profile_data.json`.
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

    // Never duplicate or overwrite: seed only an empty account.
    final existing = await Future.wait([
      _client.from('family_members').select('id').eq('user_id', uid).limit(1),
      _client.from('medical_records').select('id').eq('user_id', uid).limit(1),
      _client.from('lab_results').select('id').eq('user_id', uid).limit(1),
    ]);
    if (existing.any((rows) => rows.isNotEmpty)) {
      return const SeedResult.skipped();
    }

    final json = await _loadSample(_bundle);
    final now = DateTime.now();
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
}

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
    );
  }
}

final sampleDataRepositoryProvider = Provider<SampleDataRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeSampleDataRepository()
      : SupabaseSampleDataRepository(ref.watch(supabaseClientProvider)),
);
