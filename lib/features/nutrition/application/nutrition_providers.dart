import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend.dart';
import '../../../core/data/user.dart';
import '../data/models.dart';
import '../data/nutrition_repository.dart';
import 'nutrition_math.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Food catalog (`foods`).
final foodsCatalogProvider = FutureProvider<List<Food>>(
  (ref) => ref.watch(nutritionRepositoryProvider).foods(),
);

/// Diary of one day. Pass the date without time
/// (`DateTime(y, m, d)`), otherwise each call is a new cache key.
final dayLogsProvider = FutureProvider.family<List<FoodLog>, DateTime>((
  ref,
  day,
) {
  ref.watch(authStateProvider);
  return ref.watch(nutritionRepositoryProvider).logsFor(_day(day));
});

/// Glasses of water on a day.
final waterProvider = FutureProvider.family<int, DateTime>((ref, day) {
  ref.watch(authStateProvider);
  return ref.watch(nutritionRepositoryProvider).waterFor(_day(day));
});

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
