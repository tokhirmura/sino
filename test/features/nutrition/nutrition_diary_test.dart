import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/core/backend/backend.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/features/nutrition/application/nutrition_math.dart';
import 'package:sino/features/nutrition/application/nutrition_providers.dart';
import 'package:sino/features/nutrition/data/models.dart';
import 'package:sino/features/nutrition/data/nutrition_repository.dart';

/// Fake repo whose writes wait for [gate] and fail when [fail] is set —
/// to see the optimistic state and the rollback.
class _GatedRepo extends FakeNutritionRepository {
  _GatedRepo(super.prefs);

  Completer<void> gate = Completer<void>()..complete();
  bool fail = false;

  /// Water / servings values that fail once written.
  final failValues = <num>{};

  /// Values of setWater / updateServings in the order they ran.
  final written = <num>[];

  bool failLogs = false;

  Future<void> _write([num? v]) async {
    await gate.future;
    if (v != null) written.add(v);
    if (fail || failValues.contains(v)) throw Exception('network');
  }

  @override
  Future<List<FoodLog>> logsFor(DateTime day) async {
    if (failLogs) throw Exception('offline');
    return super.logsFor(day);
  }

  @override
  Future<FoodLog> addLog({
    required DateTime day,
    required Meal meal,
    required Food food,
    double servings = 1,
  }) async {
    await _write();
    return super.addLog(day: day, meal: meal, food: food, servings: servings);
  }

  @override
  Future<void> updateServings(String logId, double servings) async {
    await _write(servings);
    return super.updateServings(logId, servings);
  }

  @override
  Future<void> removeLog(String logId) async {
    await _write();
    return super.removeLog(logId);
  }

  @override
  Future<void> setWater(DateTime day, int glasses) async {
    await _write(glasses);
    return super.setWater(day, glasses);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('water hint', () {
    final day = DateTime(2026, 11, 14);

    test('pace spreads the goal over 08:00–22:00', () {
      expect(expectedWaterBy(DateTime(2026, 11, 14, 7)), 0);
      expect(expectedWaterBy(DateTime(2026, 11, 14, 15)), 4);
      expect(expectedWaterBy(DateTime(2026, 11, 14, 23)), 8);
    });

    test('statuses', () {
      final afternoon = DateTime(2026, 11, 14, 15);
      expect(
        waterHint(glasses: 8, day: day, now: afternoon).status,
        WaterStatus.done,
      );
      expect(
        waterHint(glasses: 3, day: day, now: afternoon).status,
        WaterStatus.onTrack,
      );
      final behind = waterHint(glasses: 1, day: day, now: afternoon);
      expect(behind.status, WaterStatus.behind);
      expect(behind.missing, 3);
      final missed = waterHint(
        glasses: 5,
        day: day,
        now: DateTime(2026, 11, 15, 9),
      );
      expect(missed.status, WaterStatus.missed);
      expect(missed.missing, 3);
    });
  });

  group('providers', () {
    late ProviderContainer container;
    late _GatedRepo repo;
    final day = DateTime(2026, 11, 20);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = _GatedRepo(prefs);
      container = ProviderContainer(
        // No automatic retries: failed loads must fail right away in tests.
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          useFakeProvider.overrideWithValue(true),
          nutritionRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
    });

    Future<Food> food(String slug) async =>
        (await repo.foods()).firstWhere((f) => f.slug == slug);

    List<FoodLog> logs() => container.read(dayLogsProvider(day)).value!;

    test('add is optimistic, then replaced by the saved row', () async {
      await container.read(dayLogsProvider(day).future);
      repo.gate = Completer<void>();
      final palov = await food('palov');
      final future = container
          .read(dayLogsProvider(day).notifier)
          .add(palov, Meal.lunch, servings: 1.5);

      expect(logs(), hasLength(1));
      expect(isPendingLog(logs().single), isTrue);
      expect(totalsOf(logs()).kcal, 900);

      repo.gate.complete();
      await future;
      expect(isPendingLog(logs().single), isFalse);
      expect(await repo.logsFor(day), hasLength(1));
    });

    test('failed add, servings and remove roll back', () async {
      await container.read(dayLogsProvider(day).future);
      final notifier = container.read(dayLogsProvider(day).notifier);
      await notifier.add(await food('palov'), Meal.lunch);
      final id = logs().single.id;

      repo.fail = true;
      await expectLater(
        notifier.add(await food('olma'), Meal.snack),
        throwsException,
      );
      expect(logs(), hasLength(1));

      await expectLater(notifier.setServings(id, 2), throwsException);
      expect(logs().single.servings, 1);

      await expectLater(notifier.remove(id), throwsException);
      expect(logs().single.id, id);
    });

    test('servings snap to 0.5 and remove returns the log', () async {
      await container.read(dayLogsProvider(day).future);
      final notifier = container.read(dayLogsProvider(day).notifier);
      await notifier.add(await food('palov'), Meal.lunch);
      final id = logs().single.id;

      await notifier.setServings(id, 2.3);
      expect(logs().single.servings, 2.5);
      expect((await repo.logsFor(day)).single.servings, 2.5);

      final removed = await notifier.remove(id);
      expect(removed?.food.slug, 'palov');
      expect(logs(), isEmpty);
      expect(await repo.logsFor(day), isEmpty);
    });

    test('water is optimistic and clamped', () async {
      await container.read(waterProvider(day).future);
      final water = container.read(waterProvider(day).notifier);
      await water.set(3);
      expect(container.read(waterProvider(day)).value, 3);
      await water.set(-5);
      expect(await repo.waterFor(day), 0);

      repo.fail = true;
      await expectLater(water.set(4), throwsException);
      expect(container.read(waterProvider(day)).value, 0);
    });

    test('manual goal overrides the profile and can be reset', () async {
      final fromProfile = await container.read(kcalGoalProvider.future);
      expect(fromProfile, greaterThan(0));

      await container.read(manualKcalGoalProvider.notifier).set(1800);
      expect(await container.read(kcalGoalProvider.future), 1800);

      await container.read(manualKcalGoalProvider.notifier).set(99999);
      expect(container.read(manualKcalGoalProvider), maxKcalGoal);

      await container.read(manualKcalGoalProvider.notifier).set(null);
      expect(await container.read(kcalGoalProvider.future), fromProfile);
    });

    test('quick water taps are written in order; stale failure keeps the '
        'newer value', () async {
      await container.read(waterProvider(day).future);
      final water = container.read(waterProvider(day).notifier);
      repo.gate = Completer<void>();
      repo.failValues.add(1);
      final a = water.set(1);
      final b = water.set(2);
      expect(container.read(waterProvider(day)).value, 2);
      repo.gate.complete();
      await expectLater(a, throwsException);
      await b;
      expect(repo.written, [1, 2]);
      expect(container.read(waterProvider(day)).value, 2);
      expect(await repo.waterFor(day), 2);
    });

    test(
      'failed latest water write rolls back to the confirmed value',
      () async {
        await container.read(waterProvider(day).future);
        final water = container.read(waterProvider(day).notifier);
        await water.set(2);
        repo.failValues.add(4);
        await water.set(3);
        await expectLater(water.set(4), throwsException);
        expect(container.read(waterProvider(day)).value, 3);
      },
    );

    test(
      'quick servings taps: ordered writes, rollback to confirmed',
      () async {
        await container.read(dayLogsProvider(day).future);
        final notifier = container.read(dayLogsProvider(day).notifier);
        await notifier.add(await food('palov'), Meal.lunch);
        final id = logs().single.id;

        repo.gate = Completer<void>();
        repo.failValues.addAll([1.5, 2.5]);
        final a = notifier.setServings(id, 1.5);
        final b = notifier.setServings(id, 2);
        final c = notifier.setServings(id, 2.5);
        repo.gate.complete();
        await expectLater(a, throwsException);
        await b;
        await expectLater(c, throwsException);
        expect(repo.written, [1.5, 2, 2.5]);
        expect(logs().single.servings, 2);
        expect((await repo.logsFor(day)).single.servings, 2);
      },
    );

    test('servings are capped at maxServings', () async {
      await container.read(dayLogsProvider(day).future);
      final notifier = container.read(dayLogsProvider(day).notifier);
      await notifier.add(await food('palov'), Meal.lunch, servings: 40);
      expect(logs().single.servings, maxServings);
    });

    test('add on a failed load rethrows and keeps the error', () async {
      repo.failLogs = true;
      await expectLater(
        container.read(dayLogsProvider(day).future),
        throwsException,
      );
      await expectLater(
        container
            .read(dayLogsProvider(day).notifier)
            .add(await food('palov'), Meal.lunch),
        throwsException,
      );
      expect(container.read(dayLogsProvider(day)).hasError, isTrue);
    });

    test('failed remove puts the log back in time order', () async {
      await container.read(dayLogsProvider(day).future);
      final notifier = container.read(dayLogsProvider(day).notifier);
      await notifier.add(await food('palov'), Meal.lunch);
      await notifier.add(await food('olma'), Meal.lunch);
      await notifier.add(await food('non'), Meal.lunch);
      final first = logs().first.id;
      repo.fail = true;
      final r1 = notifier.remove(first);
      final r2 = notifier.remove(logs().first.id);
      await expectLater(r1, throwsException);
      await expectLater(r2, throwsException);
      expect([for (final l in logs()) l.food.slug], ['palov', 'olma', 'non']);
    });

    test('selected day is clamped to the history range', () {
      final notifier = container.read(selectedDayProvider.notifier);
      final today = dayOf(DateTime.now());
      notifier.select(DateTime(2000));
      expect(
        container.read(selectedDayProvider),
        DateTime(today.year, today.month, today.day - nutritionHistoryDays),
      );
    });

    test('selected day never goes into the future', () {
      final notifier = container.read(selectedDayProvider.notifier);
      final today = dayOf(DateTime.now());
      notifier.shift(1);
      expect(container.read(selectedDayProvider), today);
      notifier.shift(-1);
      expect(
        container.read(selectedDayProvider),
        DateTime(today.year, today.month, today.day - 1),
      );
    });
  });
}
