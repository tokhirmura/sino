import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/features/vitals/application/breathing.dart';
import 'package:sino/features/vitals/presentation/breathing_screen.dart';

BreathState _at(double s, [int cycles = 4]) =>
    breathStateAt(Duration(milliseconds: (s * 1000).round()), cycles);

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  group('4-7-8 timing', () {
    test('phases and the big number', () {
      expect(_at(0).phase, BreathPhase.inhale);
      expect(_at(0).secondsLeft, 4);
      expect(_at(0.5).secondsLeft, 4);
      expect(_at(1).secondsLeft, 3);
      expect(_at(3.99).phase, BreathPhase.inhale);
      expect(_at(4).phase, BreathPhase.hold);
      expect(_at(4).secondsLeft, 7);
      expect(_at(10.99).phase, BreathPhase.hold);
      expect(_at(11).phase, BreathPhase.exhale);
      expect(_at(11).secondsLeft, 8);
      expect(_at(18.99).secondsLeft, 1);
      expect(_at(18.99).cycle, 1);
      expect(_at(19).cycle, 2);
      expect(_at(19).phase, BreathPhase.inhale);
    });

    test('done after cycles × 19 s', () {
      expect(_at(75.9).done, isFalse);
      expect(_at(75.9).cycle, 4);
      expect(_at(76).done, isTrue);
      expect(_at(500).done, isTrue);
      expect(_at(113.9, 6).done, isFalse);
      expect(breathTotal(8), const Duration(minutes: 2, seconds: 32));
    });

    test('circle grows on inhale, stays on hold, shrinks on exhale', () {
      expect(_at(0).scale, breathMinScale);
      expect(
        _at(2).scale,
        closeTo((breathMinScale + breathMaxScale) / 2, 1e-9),
      );
      expect(_at(4).scale, breathMaxScale);
      expect(_at(8).scale, breathMaxScale);
      expect(
        _at(15).scale,
        closeTo((breathMinScale + breathMaxScale) / 2, 1e-9),
      );
      expect(_at(18.999).scale, closeTo(breathMinScale, 1e-3));
      // Monotonic within a phase.
      expect(_at(1).scale, lessThan(_at(3).scale));
      expect(_at(12).scale, greaterThan(_at(16).scale));
    });
  });

  testWidgets('from home: start, phases, pause, finish, again, close', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'core.fake_signed_in': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(prefs: prefs, useFake: true),
        child: const SinoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('breathing-home-card')));
    await tester.pumpAndSettle();
    expect(find.byType(BreathingScreen), findsOneWidget);
    expect(find.text('4 · 1 daq 16 s'), findsOneWidget);
    await tester.tap(find.byKey(const Key('breath-cycles-4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('breath-start')));
    await tester.pump();

    expect(_text(tester, 'breath-phase'), 'Nafas oling');
    expect(_text(tester, 'breath-count'), '4');
    expect(_text(tester, 'breath-cycle'), '1-sikl / 4');
    await tester.pump(const Duration(seconds: 1));
    expect(_text(tester, 'breath-count'), '3');
    await tester.pump(const Duration(milliseconds: 3500));
    expect(_text(tester, 'breath-phase'), 'Ushlab turing');
    expect(_text(tester, 'breath-count'), '7');

    // Pause keeps time still.
    await tester.tap(find.byKey(const Key('breath-pause')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(_text(tester, 'breath-phase'), 'Ushlab turing');
    expect(_text(tester, 'breath-count'), '7');
    await tester.tap(find.byKey(const Key('breath-pause')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    expect(_text(tester, 'breath-phase'), 'Nafas chiqaring');

    await tester.pump(const Duration(seconds: 8));
    expect(_text(tester, 'breath-cycle'), '2-sikl / 4');
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(_text(tester, 'breath-done'), 'Barakalla!');
    expect(_text(tester, 'breath-summary'), '4 sikl · 1 daq 16 s');

    await tester.tap(find.byKey(const Key('breath-again')));
    await tester.pump();
    expect(_text(tester, 'breath-cycle'), '1-sikl / 4');
    expect(_text(tester, 'breath-count'), '4');
    await tester.tap(find.byKey(const Key('breath-stop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('breath-start')), findsOneWidget);

    // pageBack() looks for the English «Back» tooltip; the app is in Uzbek.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(BreathingScreen), findsNothing);
    expect(find.byKey(const Key('breathing-home-card')), findsOneWidget);
  });
}
