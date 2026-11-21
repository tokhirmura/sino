import 'package:flutter_test/flutter_test.dart';
import 'package:sino/features/vitals/application/steps.dart';

final _d = DateTime(2026, 11, 21);
DateTime _at(int h, [int m = 0, int dayOffset = 0]) =>
    DateTime(2026, 11, 21 + dayOffset, h, m);

void main() {
  group('applyStepCount', () {
    test('first reading is the baseline: 0 steps', () {
      final u = applyStepCount(null, 52000, _at(8));
      expect(u.today.steps, 0);
      expect(u.today.day, _d);
      expect(u.finished, isNull);
    });

    test('later readings add up', () {
      var s = applyStepCount(null, 52000, _at(8)).today;
      s = applyStepCount(s, 52350, _at(9)).today;
      s = applyStepCount(s, 55100, _at(13)).today;
      expect(s.steps, 3100);
    });

    test('a reboot keeps what was counted', () {
      var s = applyStepCount(null, 52000, _at(8)).today;
      s = applyStepCount(s, 54000, _at(10)).today; // 2000
      s = applyStepCount(s, 120, _at(11)).today; // rebooted
      expect(s.steps, 2120);
      s = applyStepCount(s, 1120, _at(12)).today;
      expect(s.steps, 3120);
    });

    test('a new day: yesterday is finished, today starts at 0', () {
      var s = applyStepCount(null, 1000, _at(8)).today;
      s = applyStepCount(s, 9500, _at(23, 50)).today; // 8500
      final u = applyStepCount(s, 9600, _at(7, 0, 1));
      expect(u.finished!.steps, 8500);
      expect(u.finished!.day, _d);
      expect(u.today.day, DateTime(2026, 11, 22));
      expect(u.today.steps, 0);
    });

    test('a clock moved back does not «finish» a future day', () {
      final s = applyStepCount(null, 1000, _at(8, 0, 1)).today;
      final u = applyStepCount(s, 1200, _at(8));
      expect(u.finished, isNull);
      expect(u.today.day, _d);
    });
  });

  test('StepsDay survives prefs', () {
    final s = StepsDay(day: _d, baseline: 10, lastCount: 500, carried: 30);
    expect(StepsDay.tryFromJson(s.toJson()), s);
    expect(StepsDay.tryFromJson({'day': 'x'}), isNull);
    expect(StepsDay.tryFromJson(null), isNull);
  });

  group('shouldSaveSteps', () {
    bool save(int steps, int? saved, DateTime now, DateTime? at) =>
        shouldSaveSteps(steps: steps, savedSteps: saved, now: now, savedAt: at);

    test('first value of the day — yes; nothing / unchanged — no', () {
      expect(save(10, null, _at(9), null), isTrue);
      expect(save(0, null, _at(9), null), isFalse);
      expect(save(800, 800, _at(12), _at(9)), isFalse);
    });

    test('every 5 minutes or every 500 steps', () {
      expect(save(900, 800, _at(9, 4), _at(9)), isFalse);
      expect(save(900, 800, _at(9, 5), _at(9)), isTrue);
      expect(save(1300, 800, _at(9, 1), _at(9)), isTrue);
    });

    test('a write from another day does not hold today back', () {
      expect(save(50, 40, _at(0, 1, 1), _at(23, 59)), isTrue);
    });
  });

  test('~km and ~kcal', () {
    expect(stepsKm(8000), closeTo(6.0, 0.001));
    expect(stepsKcal(8000), 320);
  });
}
