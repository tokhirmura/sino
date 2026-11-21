import 'package:flutter_test/flutter_test.dart';
import 'package:sino/features/weather/application/weather_logic.dart';

DayPart _at(int h, [int m = 0]) => dayPartOf(DateTime(2026, 11, 21, h, m));

void main() {
  test('tong 05–10, kun 10–17, kech 17–21, tun 21–05', () {
    expect(_at(4, 59), DayPart.night);
    expect(_at(5), DayPart.morning);
    expect(_at(9, 59), DayPart.morning);
    expect(_at(10), DayPart.day);
    expect(_at(16, 59), DayPart.day);
    expect(_at(17), DayPart.evening);
    expect(_at(20, 59), DayPart.evening);
    expect(_at(21), DayPart.night);
    expect(_at(0), DayPart.night);
  });

  test('every hour has a part', () {
    final parts = {for (var h = 0; h < 24; h++) _at(h)};
    expect(parts, DayPart.values.toSet());
  });
}
