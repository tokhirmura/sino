import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/features/workouts/application/voice_coach.dart';
import 'package:sino/features/workouts/application/voice_providers.dart';
import 'package:sino/features/workouts/data/models.dart';
import 'package:sino/features/workouts/data/voice.dart';
import 'package:sino/features/workouts/data/workouts_repository.dart';

const _plank = 'e0000000-0000-4000-8000-000000000003';

/// The app (Uzbek) with a one-exercise plan for today; the phone has only
/// Russian and English voices.
Future<(SharedPreferences, FakeSpeaker)> _pump(WidgetTester tester) async {
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
        items: const [PlanItem(exerciseId: _plank, sets: 1, seconds: 10)],
        minutes: 1,
        kcal: 5,
      ),
    ],
  );
  SharedPreferences.setMockInitialValues({
    'core.fake_signed_in': true,
    FakeWorkoutsRepository.planKey: jsonEncode(plan.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  final speaker = FakeSpeaker();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appOverrides(prefs: prefs, useFake: true),
        speakerProvider.overrideWithValue(speaker),
      ],
      child: const SinoApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('workouts-home-start')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return (prefs, speaker);
}

Future<void> _seconds(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('no Uzbek voice → counts in Russian; confetti at the end', (
    tester,
  ) async {
    final (_, speaker) = await _pump(tester);
    // The voices load a moment later; the greeting comes first anyway.
    await _seconds(tester, 5);
    expect(speaker.said.first.$1, VoiceLang.ru);
    expect(speaker.said.first.$2, startsWith('Приготовьтесь. Первое'));
    final words = [for (final s in speaker.said) s.$2];
    expect(words, containsAllInOrder(['три', 'два', 'раз']));
    expect(words.last, contains('Начали!'));

    // The 10 s plank to the end → «done» phrase, confetti, XP.
    await _seconds(tester, 10);
    expect(speaker.said.last.$2, 'Тренировка окончена! Молодец!');
    expect(find.byKey(const Key('player-confetti')), findsOneWidget);
    await tester.pumpAndSettle();
    // The confetti leaves the tree once the burst is over.
    expect(find.byKey(const Key('player-confetti')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('player-finish-xp'))).data,
      startsWith('+'),
    );
  });

  testWidgets('the voice sheet: Uzbek is marked missing; «off» silences', (
    tester,
  ) async {
    final (prefs, speaker) = await _pump(tester);
    await tester.tap(find.byKey(const Key('player-voice')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Hozir: Русский'), findsOneWidget);
    expect(find.text('Telefonda bu ovoz yo‘q'), findsOneWidget);

    await tester.tap(find.byKey(const Key('player-voice-off')));
    await tester.pump();
    expect(prefs.getString(VoiceChoiceNotifier.key), 'off');
    await tester.tapAt(const Offset(10, 10)); // close the sheet
    await tester.pump(const Duration(milliseconds: 400));

    final before = speaker.said.length;
    await _seconds(tester, 8);
    expect(speaker.said.length, before);

    // Leaving stops the voice.
    await tester.tap(find.byKey(const Key('player-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('player-exit-discard')));
    await tester.pumpAndSettle();
    expect(speaker.stops, greaterThan(0));
  });
}
