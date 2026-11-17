import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/features/workouts/data/models.dart';
import 'package:sino/features/workouts/data/workouts_repository.dart';
import 'package:sino/features/workouts/presentation/workout_player_screen.dart';

const _plank = 'e0000000-0000-4000-8000-000000000003';
const _pushUps = 'e0000000-0000-4000-8000-000000000001';

/// Home with a plan whose day 1 is today: plank 2 × 10 s, push-ups 1 × 12;
/// goal «lose» → 30 s rest.
Future<SharedPreferences> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final plan = WorkoutPlan(
    id: 'p1',
    params: const {'type': 'home', 'goal': 'lose', 'days': 2},
    days: [
      PlanDay(
        day: 1,
        weekday: DateTime.now().weekday,
        items: const [
          PlanItem(exerciseId: _plank, sets: 2, seconds: 10),
          PlanItem(exerciseId: _pushUps, sets: 1, reps: 12),
        ],
        minutes: 2,
        kcal: 10,
      ),
    ],
  );
  SharedPreferences.setMockInitialValues({
    'core.fake_signed_in': true,
    FakeWorkoutsRepository.planKey: jsonEncode(plan.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(prefs: prefs, useFake: true),
      child: const SinoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

/// Enters the player from the home card (its timer runs — no pumpAndSettle).
Future<void> _start(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('workouts-home-start')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(WorkoutPlayerScreen), findsOneWidget);
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

Future<void> _seconds(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('timer, skip rest, finish screen; home streak goes 2 → 3', (
    tester,
  ) async {
    final prefs = await _pumpHome(tester);
    // Demo sessions: yesterday and the day before.
    expect(find.text('🔥 2'), findsOneWidget);

    await _start(tester);
    expect(_text(tester, 'player-phase'), 'Tayyorlaning');
    expect(_text(tester, 'player-timer'), '0:05');
    await _seconds(tester, 1);
    expect(_text(tester, 'player-timer'), '0:04');
    await tester.tap(find.byKey(const Key('player-skip'))); // «Boshlash»
    await tester.pump();

    // Timed set: the timer counts down and moves on by itself.
    expect(_text(tester, 'player-phase'), '1-set / 2');
    expect(_text(tester, 'player-exercise'), 'Planka');
    expect(_text(tester, 'player-timer'), '0:10');
    await _seconds(tester, 3);
    expect(_text(tester, 'player-timer'), '0:07');
    // Pause stops it.
    await tester.tap(find.byKey(const Key('player-pause')));
    await tester.pump();
    await _seconds(tester, 5);
    expect(_text(tester, 'player-timer'), '0:07');
    await tester.tap(find.byKey(const Key('player-pause')));
    await tester.pump();
    await _seconds(tester, 7);

    // Rest: countdown, «+15 s», skip.
    expect(_text(tester, 'player-phase'), 'Dam olish');
    expect(_text(tester, 'player-timer'), '0:30');
    await _seconds(tester, 2);
    expect(_text(tester, 'player-timer'), '0:28');
    await tester.tap(find.byKey(const Key('player-add-rest')));
    await tester.pump();
    expect(_text(tester, 'player-timer'), '0:43');
    await tester.tap(find.byKey(const Key('player-skip')));
    await tester.pump();
    expect(_text(tester, 'player-phase'), '2-set / 2');

    await _seconds(tester, 10);
    expect(_text(tester, 'player-phase'), 'Dam olish');
    await tester.tap(find.byKey(const Key('player-skip')));
    await tester.pump();

    // Reps: no countdown, «Bajarildi».
    expect(find.byKey(const Key('player-reps')), findsOneWidget);
    expect(_text(tester, 'player-reps'), '× 12');
    await tester.tap(find.byKey(const Key('player-done')));
    await tester.pumpAndSettle(); // timer stopped

    // Finish screen.
    expect(_text(tester, 'player-finish-title'), 'Mashg‘ulot tugadi!');
    expect(_text(tester, 'player-finish-sets'), '3 / 3 set bajarildi');
    expect(_text(tester, 'player-finish-kcal'), startsWith('~'));
    // plank 20 s × 4.5 + push-ups 36 s × 7 + rest 2 s × 2 kcal/min ≈ 6 kcal
    expect(_text(tester, 'player-finish-kcal'), '~6');
    expect(_text(tester, 'player-finish-xp'), '+${6 + 15 + 20}');
    expect(_text(tester, 'player-finish-streak'), 'Ketma-ket 3 kun!');
    final saved = jsonDecode(
      prefs.getString(FakeWorkoutsRepository.sessionsKey)!,
    ) as List;
    expect(saved, hasLength(4));
    expect((saved.last as Map)['plan_day'], 1);

    await tester.tap(find.byKey(const Key('player-finish-close')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutPlayerScreen), findsNothing);
    expect(find.text('🔥 3'), findsOneWidget);
    // Today's workout is done → the home card points to the next one.
    expect(find.byKey(const Key('workouts-home-start')), findsNothing);
  });

  testWidgets('leaving mid-workout asks; «continue» keeps it, «leave» saves '
      'nothing', (tester) async {
    final prefs = await _pumpHome(tester);
    await _start(tester);
    await tester.tap(find.byKey(const Key('player-skip')));
    await tester.pump();
    await _seconds(tester, 2);

    await tester.tap(find.byKey(const Key('player-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mashg‘ulotni to‘xtatasizmi?'), findsOneWidget);
    // Paused while the dialog is open.
    final before = _text(tester, 'player-timer');
    await _seconds(tester, 3);
    expect(_text(tester, 'player-timer'), before);

    await tester.tap(find.byKey(const Key('player-exit-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _seconds(tester, 1);
    expect(_text(tester, 'player-timer'), isNot(before)); // running again

    await tester.tap(find.byKey(const Key('player-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('player-exit-discard')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutPlayerScreen), findsNothing);
    expect(find.text('🔥 2'), findsOneWidget);
    final saved = jsonDecode(
      prefs.getString(FakeWorkoutsRepository.sessionsKey)!,
    ) as List;
    expect(saved, hasLength(3));
  });

  testWidgets('«Finish» in the dialog saves the sets done so far', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _start(tester);
    await tester.tap(find.byKey(const Key('player-skip')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('player-done'))); // plank set 1
    await tester.pump();
    await tester.tap(find.byKey(const Key('player-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('player-exit-finish')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'player-finish-title'), 'Yaxshi ish!');
    expect(_text(tester, 'player-finish-sets'), '1 / 3 set bajarildi');
    expect(_text(tester, 'player-finish-streak'), 'Ketma-ket 3 kun!');
  });
}
