import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend.dart';
import '../../../core/data/user.dart';
import '../../../core/storage/prefs.dart';
import '../data/dasturxon.dart';
import '../data/models.dart';
import '../data/nutrition_repository.dart';
import 'nutrition_math.dart';

/// Date without the time part — the key of every per-day provider.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Food catalog (`foods`).
final foodsCatalogProvider = FutureProvider<List<Food>>(
  (ref) => ref.watch(nutritionRepositoryProvider).foods(),
);

/// «Dasturxon» dishes from assets (S2-1).
final dasturxonItemsProvider = FutureProvider<List<DasturxonItem>>(
  (ref) => loadDasturxon(),
);

/// Dasturxon dishes joined with the catalog (same uuids in assets and
/// Supabase), in the asset order; dishes missing from the catalog or without
/// a portion in grams are skipped.
final dasturxonProvider = FutureProvider<List<DasturxonDish>>((ref) async {
  final items = await ref.watch(dasturxonItemsProvider.future);
  final foods = await ref.watch(foodsCatalogProvider.future);
  final byId = {for (final f in foods) f.id: f};
  return [
    for (final i in items)
      if (byId[i.foodId] case final f? when f.portionGrams != null)
        (item: i, food: f),
  ];
});

/// How far back the diary goes (days before today).
const nutritionHistoryDays = 365;

/// Day shown on the nutrition screen: today by default, never in the
/// future nor older than [nutritionHistoryDays]. If the app stays open past
/// midnight while «today» is shown, it moves on to the new day.
class SelectedDayNotifier extends Notifier<DateTime> {
  Timer? _midnight;

  @override
  DateTime build() {
    ref.onDispose(() => _midnight?.cancel());
    _scheduleMidnight();
    return dayOf(DateTime.now());
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final today = dayOf(now);
    final next = DateTime(today.year, today.month, today.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), () {
      if (!ref.mounted) return;
      if (state == today) state = dayOf(DateTime.now());
      _scheduleMidnight();
    });
  }

  void select(DateTime day) {
    final today = dayOf(DateTime.now());
    final first = DateTime(
      today.year,
      today.month,
      today.day - nutritionHistoryDays,
    );
    final d = dayOf(day);
    state = d.isAfter(today)
        ? today
        : d.isBefore(first)
        ? first
        : d;
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

/// Runs writes one after another in call order, so quick taps never reach
/// the server out of order. A failed write does not block the next ones.
class _WriteQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}

/// Diary of one day with optimistic add / servings / remove: the UI
/// changes at once, writes go to the server in order, a failed write rolls
/// its change back (unless a newer change replaced it) and rethrows.
class DayLogsNotifier extends AsyncNotifier<List<FoodLog>> {
  DayLogsNotifier(DateTime day) : day = dayOf(day);

  final DateTime day;
  final _queue = _WriteQueue();

  /// Last servings the server confirmed, per log (rollback target).
  final _confirmedServings = <String, double>{};

  NutritionRepository get _repo => ref.read(nutritionRepositoryProvider);

  List<FoodLog> get _current => state.value ?? const [];

  @override
  Future<List<FoodLog>> build() {
    ref.watch(authStateProvider);
    _confirmedServings.clear();
    return ref.watch(nutritionRepositoryProvider).logsFor(day);
  }

  Future<void> add(Food food, Meal meal, {double servings = 1}) async {
    // Failed load: refuse (the screen shows the error with «Retry»; Riverpod
    // may be retrying it). Still loading: wait, so the optimistic row is not
    // lost when the load completes.
    final err = state.error;
    if (state.hasError && err != null) {
      Error.throwWithStackTrace(err, state.stackTrace ?? StackTrace.current);
    }
    if (state.isLoading) await future;
    if (!ref.mounted) return;
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
      final saved = await _queue.run(
        () => _repo.addLog(
          day: day,
          meal: meal,
          food: food,
          servings: temp.servings,
        ),
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
    _confirmedServings.putIfAbsent(logId, () => old.servings);
    _replace(logId, (l) => l.copyWith(servings: value));
    try {
      await _queue.run(() => _repo.updateServings(logId, value));
      _confirmedServings[logId] = value;
    } catch (_) {
      // Roll back only if no newer tap has changed the portion since.
      if (ref.mounted && _find(logId)?.servings == value) {
        final back = _confirmedServings[logId] ?? old.servings;
        _replace(logId, (l) => l.copyWith(servings: back));
      }
      rethrow;
    }
  }

  /// Removes the log; returns it (for «Undo») or `null` if not found.
  /// The list changes synchronously (before the first `await`).
  Future<FoodLog?> remove(String logId) async {
    final removed = _find(logId);
    if (removed == null || isPendingLog(removed)) return null;
    state = AsyncData([
      for (final l in _current)
        if (l.id != logId) l,
    ]);
    try {
      await _queue.run(() => _repo.removeLog(logId));
      _confirmedServings.remove(logId);
      return removed;
    } catch (_) {
      if (ref.mounted) state = AsyncData(_insertByTime(_current, removed));
      rethrow;
    }
  }

  /// Puts [log] back where it belongs by `createdAt` (lists are oldest first).
  static List<FoodLog> _insertByTime(List<FoodLog> list, FoodLog log) {
    final at = log.createdAt;
    final i = at == null
        ? list.length
        : list.indexWhere(
            (l) => l.createdAt != null && l.createdAt!.isAfter(at),
          );
    return [...list]..insert(i < 0 ? list.length : i, log);
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

/// Glasses of water on a day, optimistic and ordered like [DayLogsNotifier].
class WaterNotifier extends AsyncNotifier<int> {
  WaterNotifier(DateTime day) : day = dayOf(day);

  final DateTime day;
  final _queue = _WriteQueue();

  /// Last count the server confirmed (rollback target).
  int? _confirmed;

  @override
  Future<int> build() {
    ref.watch(authStateProvider);
    _confirmed = null;
    return ref.watch(nutritionRepositoryProvider).waterFor(day);
  }

  Future<void> set(int glasses) async {
    final old = state.value ?? 0;
    final value = glasses.clamp(0, maxWaterGlasses);
    if (value == old) return;
    _confirmed ??= old;
    state = AsyncData(value);
    try {
      await _queue.run(
        () => ref.read(nutritionRepositoryProvider).setWater(day, value),
      );
      _confirmed = value;
    } catch (_) {
      // Roll back only if no newer tap has changed the count since.
      if (ref.mounted && state.value == value) {
        state = AsyncData(_confirmed ?? old);
      }
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
