import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';
import '../../../core/storage/prefs.dart';
import 'models.dart';

/// Exercise catalog + the user's plans and finished sessions.
abstract class WorkoutsRepository {
  /// Whole `exercises` catalog, or only one [type].
  Future<List<Exercise>> exercises({WorkoutType? type});

  /// The newest plan, `null` if none yet.
  Future<WorkoutPlan?> latestPlan();

  Future<WorkoutPlan> savePlan({
    required Map<String, dynamic> params,
    required List<PlanDay> days,
  });

  /// Finished sessions, newest first; only after [since] when given.
  Future<List<WorkoutSession>> sessions({DateTime? since});

  Future<WorkoutSession> addSession({int? planDay, required double kcal});
}

const _timeout = Duration(seconds: 10);

class SupabaseWorkoutsRepository implements WorkoutsRepository {
  SupabaseWorkoutsRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  @override
  Future<List<Exercise>> exercises({WorkoutType? type}) async {
    var q = _client.from('exercises').select();
    if (type != null) q = q.eq('type', type.name);
    final rows = await q.timeout(_timeout);
    return [for (final r in rows) Exercise.fromJson(r)];
  }

  @override
  Future<WorkoutPlan?> latestPlan() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('workout_plans')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(_timeout);
    return row == null ? null : WorkoutPlan.fromJson(row);
  }

  @override
  Future<WorkoutPlan> savePlan({
    required Map<String, dynamic> params,
    required List<PlanDay> days,
  }) async {
    final row = await _client
        .from('workout_plans')
        .insert({
          'user_id': _uid,
          'params': params,
          'plan': [for (final d in days) d.toJson()],
        })
        .select()
        .single()
        .timeout(_timeout);
    return WorkoutPlan.fromJson(row);
  }

  @override
  Future<List<WorkoutSession>> sessions({DateTime? since}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    var q = _client.from('workout_sessions').select().eq('user_id', uid);
    if (since != null) {
      q = q.gte('finished_at', since.toUtc().toIso8601String());
    }
    final rows = await q
        .order('finished_at', ascending: false)
        .timeout(_timeout);
    return [for (final r in rows) WorkoutSession.fromJson(r)];
  }

  @override
  Future<WorkoutSession> addSession({
    int? planDay,
    required double kcal,
  }) async {
    final row = await _client
        .from('workout_sessions')
        .insert({'user_id': _uid, 'plan_day': planDay, 'kcal': kcal})
        .select()
        .single()
        .timeout(_timeout);
    return WorkoutSession.fromJson(row);
  }
}

/// Offline: catalog from `assets/wellness/exercises.json`; plan and
/// sessions in SharedPreferences, sessions start with the demo from
/// `assets/wellness/fake_wellness.json`.
class FakeWorkoutsRepository implements WorkoutsRepository {
  FakeWorkoutsRepository(this._prefs, {AssetBundle? bundle, this.now})
    : _bundle = bundle ?? rootBundle;

  final SharedPreferences _prefs;
  final AssetBundle _bundle;

  /// Fixed "now" for tests; `null` = real clock.
  final DateTime? now;

  static const exercisesAsset = 'assets/wellness/exercises.json';
  static const demoAsset = 'assets/wellness/fake_wellness.json';
  static const planKey = 'workouts.fake_plan';
  static const sessionsKey = 'workouts.fake_sessions';

  DateTime get _now => now ?? DateTime.now();

  List<Exercise>? _catalog;

  // cache: false — see FakeMedicalRepository.
  Future<String> _load(String asset) => _bundle.loadString(asset, cache: false);

  @override
  Future<List<Exercise>> exercises({WorkoutType? type}) async {
    final all = _catalog ??= [
      for (final r in jsonDecode(await _load(exercisesAsset)) as List)
        Exercise.fromJson(r as Map<String, dynamic>),
    ];
    return type == null
        ? all
        : [
            for (final e in all)
              if (e.type == type) e,
          ];
  }

  @override
  Future<WorkoutPlan?> latestPlan() async {
    final raw = _prefs.getString(planKey);
    if (raw == null) return null;
    return WorkoutPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<WorkoutPlan> savePlan({
    required Map<String, dynamic> params,
    required List<PlanDay> days,
  }) async {
    final at = DateTime.now();
    final plan = WorkoutPlan(
      id: 'fake-plan-${at.microsecondsSinceEpoch}',
      params: params,
      days: days,
      createdAt: at,
    );
    await _prefs.setString(planKey, jsonEncode(plan.toJson()));
    return plan;
  }

  Future<List<WorkoutSession>> _all() async {
    final raw = _prefs.getString(sessionsKey);
    if (raw != null) {
      return [
        for (final m in jsonDecode(raw) as List)
          WorkoutSession.fromJson(Map<String, dynamic>.from(m as Map)),
      ];
    }
    final demo = jsonDecode(await _load(demoAsset)) as Map<String, dynamic>;
    final today = DateTime(_now.year, _now.month, _now.day, 19);
    var i = 0;
    final list = [
      for (final r in demo['workout_sessions'] as List)
        WorkoutSession(
          id: 'fake-session-${i++}',
          planDay: r['plan_day'] as int?,
          kcal: (r['kcal'] as num).toDouble(),
          finishedAt: today.subtract(Duration(days: r['days_ago'] as int)),
        ),
    ];
    await _save(list);
    return list;
  }

  Future<void> _save(List<WorkoutSession> list) => _prefs.setString(
    sessionsKey,
    jsonEncode([for (final s in list) s.toJson()]),
  );

  @override
  Future<List<WorkoutSession>> sessions({DateTime? since}) async {
    final list = [
      for (final s in await _all())
        if (since == null || !s.finishedAt.isBefore(since)) s,
    ];
    return list..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
  }

  @override
  Future<WorkoutSession> addSession({
    int? planDay,
    required double kcal,
  }) async {
    final list = await _all();
    final at = DateTime.now();
    final s = WorkoutSession(
      id: 'fake-session-${at.microsecondsSinceEpoch}',
      planDay: planDay,
      kcal: kcal,
      finishedAt: at,
    );
    await _save([...list, s]);
    return s;
  }
}

final workoutsRepositoryProvider = Provider<WorkoutsRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeWorkoutsRepository(ref.watch(sharedPreferencesProvider))
      : SupabaseWorkoutsRepository(ref.watch(supabaseClientProvider)),
);
