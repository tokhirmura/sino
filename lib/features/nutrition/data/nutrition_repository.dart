import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';
import '../../../core/storage/prefs.dart';
import 'models.dart';

/// Food catalog + the user's food diary and water.
abstract class NutritionRepository {
  /// Whole `foods` catalog (sorted as in the assets / by name).
  Future<List<Food>> foods();

  /// Logs of one [day], oldest first.
  Future<List<FoodLog>> logsFor(DateTime day);

  Future<FoodLog> addLog({
    required DateTime day,
    required Meal meal,
    required Food food,
    double servings = 1,
  });

  Future<void> updateServings(String logId, double servings);

  Future<void> removeLog(String logId);

  /// Latest logs of any day, newest first (for «Recently eaten»).
  Future<List<FoodLog>> latestLogs({int limit = 60});

  /// Glasses of water on [day] (0 when nothing logged).
  Future<int> waterFor(DateTime day);

  Future<void> setWater(DateTime day, int glasses);
}

/// Search in the catalog: case-insensitive, in uz/ru/en and the slug,
/// apostrophes ignored (people type both «go‘shtli» and «goshtli»).
List<Food> searchFoods(List<Food> foods, String query) {
  final q = normalizeFoodText(query);
  if (q.isEmpty) return foods;
  return [
    for (final f in foods)
      if ([
        ...f.name.values.map((v) => '$v'),
        if (f.slug != null) f.slug!,
      ].any((s) => normalizeFoodText(s).contains(q)))
        f,
  ];
}

/// Foods of [logs] (newest first) without repeats, at most [limit]:
/// «Recently eaten». A custom food repeats when name and calories match.
List<({Food food, double servings})> recentFoods(
  Iterable<FoodLog> logs, {
  int limit = 10,
}) {
  final seen = <String>{};
  final out = <({Food food, double servings})>[];
  for (final l in logs) {
    final f = l.food;
    final key = f.isCustom
        ? 'c:${normalizeFoodText('${f.name['uz'] ?? f.name.values.firstOrNull}')}'
              '|${f.kcal.round()}'
        : f.id;
    if (!seen.add(key)) continue;
    out.add((food: f, servings: l.servings));
    if (out.length == limit) break;
  }
  return out;
}

String normalizeFoodText(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[\'‘’ʻʼ`´]'), '')
    .replaceAll('ё', 'е')
    .replaceAll('_', ' ')
    .trim();

const _timeout = Duration(seconds: 10);

class SupabaseNutritionRepository implements NutritionRepository {
  SupabaseNutritionRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  @override
  Future<List<Food>> foods() async {
    final rows = await _client.from('foods').select().timeout(_timeout);
    final list = [for (final r in rows) Food.fromJson(r)];
    return list..sort((a, b) => '${a.name['uz']}'.compareTo('${b.name['uz']}'));
  }

  @override
  Future<List<FoodLog>> logsFor(DateTime day) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('food_logs')
        .select('*, foods(*)')
        .eq('user_id', uid)
        .eq('date', dateKey(day))
        .order('created_at')
        .timeout(_timeout);
    return [for (final r in rows) FoodLog.fromJson(r)];
  }

  @override
  Future<FoodLog> addLog({
    required DateTime day,
    required Meal meal,
    required Food food,
    double servings = 1,
  }) async {
    final row = await _client
        .from('food_logs')
        .insert({
          'user_id': _uid,
          'date': dateKey(day),
          'meal': meal.name,
          'food_id': food.isCustom ? null : food.id,
          if (food.isCustom) 'custom_food': food.toJson(),
          'servings': servings,
        })
        .select('*, foods(*)')
        .single()
        .timeout(_timeout);
    return FoodLog.fromJson(row);
  }

  @override
  Future<void> updateServings(String logId, double servings) => _client
      .from('food_logs')
      .update({'servings': servings})
      .eq('id', logId)
      .timeout(_timeout);

  @override
  Future<void> removeLog(String logId) =>
      _client.from('food_logs').delete().eq('id', logId).timeout(_timeout);

  @override
  Future<List<FoodLog>> latestLogs({int limit = 60}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('food_logs')
        .select('*, foods(*)')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit)
        .timeout(_timeout);
    return [for (final r in rows) FoodLog.fromJson(r)];
  }

  @override
  Future<int> waterFor(DateTime day) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    final row = await _client
        .from('water_logs')
        .select()
        .eq('user_id', uid)
        .eq('date', dateKey(day))
        .maybeSingle()
        .timeout(_timeout);
    return row == null ? 0 : WaterLog.fromJson(row).glasses;
  }

  @override
  Future<void> setWater(DateTime day, int glasses) => _client
      .from('water_logs')
      .upsert({
        'user_id': _uid,
        'date': dateKey(day),
        'glasses': glasses < 0 ? 0 : glasses,
      }, onConflict: 'user_id,date')
      .timeout(_timeout);
}

/// Offline: catalog from `assets/wellness/foods.json`, the user's diary in
/// SharedPreferences. On first use the diary is filled with the demo from
/// `assets/wellness/fake_wellness.json` (dates relative to today).
class FakeNutritionRepository implements NutritionRepository {
  FakeNutritionRepository(this._prefs, {AssetBundle? bundle, this.now})
    : _bundle = bundle ?? rootBundle;

  final SharedPreferences _prefs;
  final AssetBundle _bundle;

  /// Fixed "today" for tests; `null` = real clock.
  final DateTime? now;

  static const foodsAsset = 'assets/wellness/foods.json';
  static const demoAsset = 'assets/wellness/fake_wellness.json';
  static const logsKey = 'nutrition.fake_logs';
  static const waterKey = 'nutrition.fake_water';

  DateTime get _today {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<Food>? _foods;

  // cache: false — a cached asset future never completes in the next
  // widget test (each test has its own fake async zone).
  Future<String> _load(String asset) => _bundle.loadString(asset, cache: false);

  @override
  Future<List<Food>> foods() async => _foods ??= [
    for (final r in jsonDecode(await _load(foodsAsset)) as List)
      Food.fromJson(r as Map<String, dynamic>),
  ];

  Future<Map<String, dynamic>> _demo() async =>
      jsonDecode(await _load(demoAsset)) as Map<String, dynamic>;

  Future<List<FoodLog>> _allLogs() async {
    final raw = _prefs.getString(logsKey);
    if (raw != null) {
      return [
        for (final m in jsonDecode(raw) as List)
          FoodLog.fromJson(Map<String, dynamic>.from(m as Map)),
      ];
    }
    final bySlug = {for (final f in await foods()) f.slug: f};
    final logs = <FoodLog>[];
    var i = 0;
    for (final r in (await _demo())['food_logs'] as List) {
      final m = r as Map<String, dynamic>;
      final food = bySlug[m['food']];
      if (food == null) continue;
      final date = _today.subtract(Duration(days: m['days_ago'] as int));
      logs.add(
        FoodLog(
          id: 'fake-log-${i++}',
          date: date,
          meal: Meal.fromName(m['meal'] as String?),
          food: food,
          servings: (m['servings'] as num).toDouble(),
          createdAt: date.add(Duration(minutes: i)),
        ),
      );
    }
    await _saveLogs(logs);
    return logs;
  }

  Future<void> _saveLogs(List<FoodLog> logs) =>
      _prefs.setString(logsKey, jsonEncode([for (final l in logs) l.toJson()]));

  @override
  Future<List<FoodLog>> logsFor(DateTime day) async {
    final key = dateKey(day);
    return [
      for (final l in await _allLogs())
        if (dateKey(l.date) == key) l,
    ];
  }

  @override
  Future<FoodLog> addLog({
    required DateTime day,
    required Meal meal,
    required Food food,
    double servings = 1,
  }) async {
    final logs = await _allLogs();
    final at = DateTime.now();
    final log = FoodLog(
      id: 'fake-log-${at.microsecondsSinceEpoch}',
      date: DateTime(day.year, day.month, day.day),
      meal: meal,
      food: food,
      servings: servings,
      createdAt: at,
    );
    await _saveLogs([...logs, log]);
    return log;
  }

  @override
  Future<void> updateServings(String logId, double servings) async {
    final logs = await _allLogs();
    await _saveLogs([
      for (final l in logs) l.id == logId ? l.copyWith(servings: servings) : l,
    ]);
  }

  @override
  Future<void> removeLog(String logId) async {
    final logs = await _allLogs();
    await _saveLogs([
      for (final l in logs)
        if (l.id != logId) l,
    ]);
  }

  @override
  Future<List<FoodLog>> latestLogs({int limit = 60}) async {
    final logs = [
      ...await _allLogs(),
    ]..sort((a, b) => (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date));
    return logs.take(limit).toList();
  }

  Future<Map<String, int>> _water() async {
    final raw = _prefs.getString(waterKey);
    if (raw != null) {
      return {
        for (final e in (jsonDecode(raw) as Map).entries)
          e.key as String: (e.value as num).toInt(),
      };
    }
    final water = <String, int>{
      for (final r in (await _demo())['water_logs'] as List)
        dateKey(_today.subtract(Duration(days: r['days_ago'] as int))):
            r['glasses'] as int,
    };
    await _prefs.setString(waterKey, jsonEncode(water));
    return water;
  }

  @override
  Future<int> waterFor(DateTime day) async =>
      (await _water())[dateKey(day)] ?? 0;

  @override
  Future<void> setWater(DateTime day, int glasses) async {
    final water = await _water();
    water[dateKey(day)] = glasses < 0 ? 0 : glasses;
    await _prefs.setString(waterKey, jsonEncode(water));
  }
}

final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeNutritionRepository(ref.watch(sharedPreferencesProvider))
      : SupabaseNutritionRepository(ref.watch(supabaseClientProvider)),
);
