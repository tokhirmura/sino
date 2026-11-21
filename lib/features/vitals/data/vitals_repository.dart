import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';
import '../../../core/storage/prefs.dart';
import 'models.dart';

/// The user's measurements (`vitals`).
abstract class VitalsRepository {
  /// Newest first; filtered by [kind] and [since] when given.
  Future<List<Vital>> list({VitalKind? kind, DateTime? since});

  Future<Vital> add({
    required VitalKind kind,
    required double value,
    double? value2,
    DateTime? measuredAt,
  });

  /// Saves several measurements at once (one request).
  Future<void> addAll(List<VitalInput> items);

  Future<void> remove(String id);

  /// Changes a row's value (and time); `false` if the row is gone (deleted
  /// by the user) — the caller adds a new one.
  Future<bool> update(String id, {required double value, DateTime? measuredAt});
}

const _timeout = Duration(seconds: 10);

class SupabaseVitalsRepository implements VitalsRepository {
  SupabaseVitalsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Vital>> list({VitalKind? kind, DateTime? since}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    var q = _client.from('vitals').select().eq('user_id', uid);
    if (kind != null) q = q.eq('kind', kind.name);
    if (since != null) {
      q = q.gte('measured_at', since.toUtc().toIso8601String());
    }
    final rows = await q
        .order('measured_at', ascending: false)
        .timeout(_timeout);
    return [for (final r in rows) ?Vital.tryFromJson(r)];
  }

  @override
  Future<Vital> add({
    required VitalKind kind,
    required double value,
    double? value2,
    DateTime? measuredAt,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    final row = await _client
        .from('vitals')
        .insert({
          'user_id': uid,
          'kind': kind.name,
          'value': value,
          'value2': value2,
          if (measuredAt != null)
            'measured_at': measuredAt.toUtc().toIso8601String(),
        })
        .select()
        .single()
        .timeout(_timeout);
    return Vital.fromJson(row);
  }

  @override
  Future<void> addAll(List<VitalInput> items) async {
    if (items.isEmpty) return;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    await _client
        .from('vitals')
        .insert([
          for (final i in items)
            {
              'user_id': uid,
              'kind': i.kind.name,
              'value': i.value,
              'value2': i.value2,
              'measured_at': i.measuredAt.toUtc().toIso8601String(),
            },
        ])
        .timeout(_timeout);
  }

  @override
  Future<void> remove(String id) =>
      _client.from('vitals').delete().eq('id', id).timeout(_timeout);

  @override
  Future<bool> update(
    String id, {
    required double value,
    DateTime? measuredAt,
  }) async {
    final rows = await _client
        .from('vitals')
        .update({
          'value': value,
          if (measuredAt != null)
            'measured_at': measuredAt.toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select('id')
        .timeout(_timeout);
    return rows.isNotEmpty;
  }
}

/// Offline: measurements in SharedPreferences, first filled with the
/// 7-day demo from `assets/wellness/fake_wellness.json`.
class FakeVitalsRepository implements VitalsRepository {
  FakeVitalsRepository(this._prefs, {AssetBundle? bundle, this.now})
    : _bundle = bundle ?? rootBundle;

  final SharedPreferences _prefs;
  final AssetBundle _bundle;

  /// Fixed "now" for tests; `null` = real clock.
  final DateTime? now;

  static const demoAsset = 'assets/wellness/fake_wellness.json';
  static const listKey = 'vitals.fake_list';

  Future<List<Vital>> _all() async {
    final raw = _prefs.getString(listKey);
    if (raw != null) {
      return [
        for (final m in jsonDecode(raw) as List)
          ?Vital.tryFromJson(Map<String, dynamic>.from(m as Map)),
      ];
    }
    // cache: false — see FakeMedicalRepository.
    final demo = jsonDecode(
      await _bundle.loadString(demoAsset, cache: false),
    ) as Map<String, dynamic>;
    final n = now ?? DateTime.now();
    final morning = DateTime(n.year, n.month, n.day, 8);
    var i = 0;
    final list = <Vital>[];
    for (final r in demo['vitals'] as List) {
      final kind = VitalKind.fromName(r['kind'] as String?);
      if (kind == null) continue;
      list.add(
        Vital(
          id: 'fake-vital-${i++}',
          kind: kind,
          value: (r['value'] as num).toDouble(),
          value2: (r['value2'] as num?)?.toDouble(),
          measuredAt: _demoTime(morning, n, r['days_ago'] as int),
        ),
      );
    }
    await _save(list);
    return list;
  }

  /// 08:00 of the demo day; today before 08:00 — a minute ago (never in
  /// the future, or a new measurement would not be the latest one).
  static DateTime _demoTime(DateTime morning, DateTime now, int daysAgo) {
    final at = DateTime(morning.year, morning.month, morning.day - daysAgo, 8);
    return at.isAfter(now) ? now.subtract(const Duration(minutes: 1)) : at;
  }

  Future<void> _save(List<Vital> list) =>
      _prefs.setString(listKey, jsonEncode([for (final v in list) v.toJson()]));

  @override
  Future<List<Vital>> list({VitalKind? kind, DateTime? since}) async {
    final list = [
      for (final v in await _all())
        if ((kind == null || v.kind == kind) &&
            (since == null || !v.measuredAt.isBefore(since)))
          v,
    ];
    return list..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
  }

  @override
  Future<Vital> add({
    required VitalKind kind,
    required double value,
    double? value2,
    DateTime? measuredAt,
  }) async {
    final list = await _all();
    final at = DateTime.now();
    final v = Vital(
      id: 'fake-vital-${at.microsecondsSinceEpoch}',
      kind: kind,
      value: value,
      value2: value2,
      measuredAt: measuredAt ?? at,
    );
    await _save([...list, v]);
    return v;
  }

  @override
  Future<void> addAll(List<VitalInput> items) async {
    final list = await _all();
    final at = DateTime.now().microsecondsSinceEpoch;
    var n = 0;
    await _save([
      ...list,
      for (final i in items)
        Vital(
          id: 'fake-vital-$at-${n++}',
          kind: i.kind,
          value: i.value,
          value2: i.value2,
          measuredAt: i.measuredAt,
        ),
    ]);
  }

  @override
  Future<void> remove(String id) async {
    final list = await _all();
    await _save([
      for (final v in list)
        if (v.id != id) v,
    ]);
  }

  @override
  Future<bool> update(
    String id, {
    required double value,
    DateTime? measuredAt,
  }) async {
    final list = await _all();
    final i = list.indexWhere((v) => v.id == id);
    if (i < 0) return false;
    final v = list[i];
    list[i] = Vital(
      id: v.id,
      kind: v.kind,
      value: value,
      value2: v.value2,
      measuredAt: measuredAt ?? v.measuredAt,
    );
    await _save(list);
    return true;
  }
}

final vitalsRepositoryProvider = Provider<VitalsRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeVitalsRepository(ref.watch(sharedPreferencesProvider))
      : SupabaseVitalsRepository(ref.watch(supabaseClientProvider)),
);
