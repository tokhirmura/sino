import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/features/workouts/data/models.dart';
import 'package:sino/features/workouts/data/workouts_repository.dart';
import 'package:sino/features/workouts/presentation/workouts_screen.dart';

Future<void> _pumpHome(WidgetTester tester, {WorkoutPlan? plan}) async {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'core.fake_signed_in': true,
    if (plan != null) FakeWorkoutsRepository.planKey: jsonEncode(plan.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(prefs: prefs, useFake: true),
      child: const SinoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

const _card = Key('workouts-home-card');

void main() {
  testWidgets('no plan → invitation, tap opens the generator', (tester) async {
    await _pumpHome(tester);
    expect(find.byKey(_card), findsOneWidget);
    expect(
      find.text('Haftalik mashg‘ulot rejangizni tuzing — 1 daqiqa'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(_card));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutsScreen), findsOneWidget);
    expect(find.byKey(const Key('workouts-generate')), findsOneWidget);
  });

  testWidgets('plan with today → «Bugun», minutes, kcal, streak', (
    tester,
  ) async {
    final today = DateTime.now().weekday;
    final tomorrow = today % 7 + 1;
    await _pumpHome(
      tester,
      plan: WorkoutPlan(
        id: 'p1',
        params: const {'type': 'gym', 'goal': 'gain', 'days': 2},
        days: [
          PlanDay(
            day: 1,
            weekday: tomorrow,
            items: const [PlanItem(exerciseId: 'x')],
            minutes: 40,
            kcal: 120,
          ),
          PlanDay(
            day: 2,
            weekday: today,
            items: const [
              PlanItem(exerciseId: 'a'),
              PlanItem(exerciseId: 'b'),
              PlanItem(exerciseId: 'c'),
            ],
            minutes: 29,
            kcal: 74,
          ),
        ],
      ),
    );
    final when = tester
        .widget<Text>(find.byKey(const Key('workouts-home-when')))
        .data!;
    expect(when, startsWith('Bugun · '));
    expect(find.text('29 daq · ~74 kkal · 3 ta mashq'), findsOneWidget);
    expect(find.text('🏋️'), findsOneWidget); // gym
    // Demo sessions: yesterday and the day before → 2-day streak.
    expect(find.text('🔥 2'), findsOneWidget);
  });
}
