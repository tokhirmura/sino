import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend.dart';
import '../data/models.dart';
import '../data/workouts_repository.dart';
import 'plan_generator.dart';
import 'workout_math.dart';

/// Whole exercise catalog.
final exercisesProvider = FutureProvider<List<Exercise>>(
  (ref) => ref.watch(workoutsRepositoryProvider).exercises(),
);

/// Catalog by id — for plan days and the player.
final exercisesByIdProvider = FutureProvider<Map<String, Exercise>>((
  ref,
) async {
  final list = await ref.watch(exercisesProvider.future);
  return {for (final e in list) e.id: e};
});

/// The newest saved plan.
final latestPlanProvider = FutureProvider<WorkoutPlan?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(workoutsRepositoryProvider).latestPlan();
});

/// Finished sessions, newest first.
final sessionsProvider = FutureProvider<List<WorkoutSession>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(workoutsRepositoryProvider).sessions();
});

/// Current streak of training days.
final streakProvider = FutureProvider<int>((ref) async {
  final sessions = await ref.watch(sessionsProvider.future);
  return streakDays(sessions, DateTime.now());
});

/// Builds a plan from [PlanParams] and saves it to `workout_plans`.
class PlanActions {
  PlanActions(this._ref);

  final Ref _ref;

  /// Generates the week from the catalog, saves it and refreshes
  /// [latestPlanProvider]. Throws if the catalog is empty or saving fails.
  Future<WorkoutPlan> create(PlanParams params) async {
    final catalog = await _ref.read(exercisesProvider.future);
    final days = generatePlan(params, catalog);
    if (days.isEmpty) throw StateError('Exercise catalog is empty');
    final plan = await _ref
        .read(workoutsRepositoryProvider)
        .savePlan(params: params.toJson(), days: days);
    _ref.invalidate(latestPlanProvider);
    return plan;
  }
}

final planActionsProvider = Provider<PlanActions>(PlanActions.new);

/// Next training of the newest plan (for the home card); `null` = no plan.
final nextWorkoutProvider =
    FutureProvider<({WorkoutPlan plan, PlanDay day, DateTime date})?>((
      ref,
    ) async {
      final plan = await ref.watch(latestPlanProvider.future);
      if (plan == null) return null;
      final sessions = await ref.watch(sessionsProvider.future);
      final next = nextWorkout(plan.days, DateTime.now(), sessions);
      if (next == null) return null;
      return (plan: plan, day: next.day, date: next.date);
    });

/// Saves finished workouts to `workout_sessions`.
class SessionActions {
  SessionActions(this._ref);

  final Ref _ref;

  /// Saves a session and refreshes the sessions, the streak and the next
  /// workout.
  Future<WorkoutSession> save({int? planDay, required double kcal}) async {
    final s = await _ref
        .read(workoutsRepositoryProvider)
        .addSession(planDay: planDay, kcal: kcal);
    _ref.invalidate(sessionsProvider);
    return s;
  }
}

final sessionActionsProvider = Provider<SessionActions>(SessionActions.new);
