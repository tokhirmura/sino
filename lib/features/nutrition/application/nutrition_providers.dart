import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend.dart';
import '../../../core/data/user.dart';
import '../../../core/storage/prefs.dart';
import '../data/models.dart';
import '../data/nutrition_repository.dart';
import 'nutrition_math.dart';

/// Date without the time part — the key of every per-day provider.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Food catalog (`foods`).
final foodsCatalogProvider = FutureProvider<List<Food>>(
  (ref) => ref.watch(nutritionRepositoryProvider).foods(),
);

/// Day shown on the nutrition screen (today by default, never in the future).
class SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dayOf(DateTime.now());

  void select(DateTime day) {
    final today = dayOf(DateTime.now());
    final d = dayOf(day);
    state = d.isAfter(today) ? today : d;
  }

  /// Calendar shift (DST-safe: day arithmetic, not hours).
  void shift(int days) =>
      select(DateTime(state.year, state.month, state.day + days));
}

final selectedDayProvider = NotifierProvider<SelectedDayNotifier, DateTime>(
  SelectedDayNotifier.new,
);

/// Prefix of ids of logs that are not saved yet (optimistic add).
const pendingLogPrefix = 'pending-';

bool isPendingLog(FoodLog l) => l.id.startsWith(pendingLogPrefix);

/// Diary of one day with optimistic add / servings / remove: the UI
/// changes at once, a failed request rolls the change back and rethrows.
class DayLogsNotifier extends AsyncNotifier<List<FoodLog>> {
  DayLogsNotifier(DateTime day) : day = dayOf(day);

  final DateTime day;

  NutritionRepository get _repo => ref.read(nutritionRepositoryProvider);

  List<FoodLog> get _current => state.value ?? const [];

  @override
  Future<List<FoodLog>> build() {
    ref.watch(authStateProvider);
    return ref.watch(nutritionRepositoryProvider).logsFor(day);
  }

  Future<void> add(Food food, Meal meal, {double servings = 1}) async {
    final temp = FoodLog(
      id: '$pendingLogPrefix${DateTime.now().microsecondsSinceEpoch}',
      date: day,
      meal: meal,
      food: food,
      servings: snapServings(servings),
      createdAt: DateTime.now(),
    );
    state = AsyncData([..._current, temp]);
    try {
      final saved = await _repo.addLog(
        day: day,
        meal: meal,
        food: food,
        servings: temp.servings,
      );
      if (!ref.mounted) return;
      state = AsyncData([
        for (final l in _current) l.id == temp.id ? saved : l,
      ]);
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData([
          for (final l in _current)
            if (l.id != temp.id) l,
        ]);
      }
      rethrow;
    }
  }

  Future<void> setServings(String logId, double servings) async {
    final old = _find(logId);
    if (old == null || isPendingLog(old)) return;
    final value = snapServings(servings);
    if (value == old.servings) return;
    _replace(logId, (l) => l.copyWith(servings: value));
    try {
      await _repo.updateServings(logId, value);
    } catch (_) {
      if (ref.mounted) {
        _replace(logId, (l) => l.copyWith(servings: old.servings));
      }
      rethrow;
    }
  }

  /// Removes the log; returns it (for «Undo») or `null` if not found.
  Future<FoodLog?> remove(String logId) async {
    final list = _current;
    final index = list.indexWhere((l) => l.id == logId);
    if (index < 0 || isPendingLog(list[index])) return null;
    final removed = list[index];
    state = AsyncData([...list]..removeAt(index));
    try {
      await _repo.removeLog(logId);
      return removed;
    } catch (_) {
      if (ref.mounted) {
        final cur = [..._current];
        cur.insert(index.clamp(0, cur.length), removed);
        state = AsyncData(cur);
      }
      rethrow;
    }
  }

  FoodLog? _find(String id) {
    for (final l in _current) {
      if (l.id == id) return l;
    }
    return null;
  }

  void _replace(String id, FoodLog Function(FoodLog) change) {
    state = AsyncData([for (final l in _current) l.id == id ? change(l) : l]);
  }
}

/// Diary of one day. Pass the date without time (`dayOf(...)`),
/// otherwise each call is a new cache key.
final dayLogsProvider =
    AsyncNotifierProvider.family<DayLogsNotifier, List<FoodLog>, DateTime>(
      DayLogsNotifier.new,
    );

/// Upper bound of the water counter (glasses).
const maxWaterGlasses = 20;

/// Glasses of water on a day, optimistic like [DayLogsNotifier].
class WaterNotifier extends AsyncNotifier<int> {
  WaterNotifier(DateTime day) : day = dayOf(day);

  final DateTime day;

  @override
  Future<int> build() {
    ref.watch(authStateProvider);
    return ref.watch(nutritionRepositoryProvider).waterFor(day);
  }

  Future<void> set(int glasses) async {
    final old = state.value ?? 0;
    final value = glasses.clamp(0, maxWaterGlasses);
    if (value == old) return;
    state = AsyncData(value);
    try {
      await ref.read(nutritionRepositoryProvider).setWater(day, value);
    } catch (_) {
      if (ref.mounted) state = AsyncData(old);
      rethrow;
    }
  }
}

final waterProvider =
    AsyncNotifierProvider.family<WaterNotifier, int, DateTime>(
      WaterNotifier.new,
    );

/// Calorie goal from the profile (Mifflin–St Jeor); [defaultKcalGoal]
/// when the profile is incomplete.
final kcalGoalFromProfileProvider = FutureProvider<int>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  return dailyKcalGoal(
        weightKg: user?.weightKg,
        heightCm: user?.heightCm,
        birthYear: user?.birthYear,
        currentYear: DateTime.now().year,
      ) ??
      defaultKcalGoal;
});

/// Allowed range of a manual calorie goal.
const minKcalGoal = 800;
const maxKcalGoal = 6000;

/// Calorie goal set by hand (prefs, per device); `null` = from the profile.
class ManualKcalGoalNotifier extends Notifier<int?> {
  static const key = 'nutrition.kcal_goal';

  @override
  int? build() => ref.watch(sharedPreferencesProvider).getInt(key);

  Future<void> set(int? goal) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (goal == null) {
      state = null;
      await prefs.remove(key);
      return;
    }
    final v = goal.clamp(minKcalGoal, maxKcalGoal);
    state = v;
    await prefs.setInt(key, v);
  }
}

final manualKcalGoalProvider = NotifierProvider<ManualKcalGoalNotifier, int?>(
  ManualKcalGoalNotifier.new,
);

/// Effective daily calorie goal: manual one if set, else from the profile.
final kcalGoalProvider = FutureProvider<int>((ref) async {
  final manual = ref.watch(manualKcalGoalProvider);
  if (manual != null) return manual;
  return ref.watch(kcalGoalFromProfileProvider.future);
});
