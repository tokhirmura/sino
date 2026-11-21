import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/features/weather/application/weather_logic.dart';
import 'package:sino/features/weather/presentation/labels.dart';

void main() {
  group('airAlert', () {
    test('no warning up to 100 or without AQI', () {
      expect(airAlert(null), isNull);
      expect(airAlert(0), isNull);
      expect(airAlert(58), isNull);
      expect(airAlert(outdoorAqiLimit), isNull);
    });

    test('above 100: a warning; above 150: severe', () {
      final a = airAlert(101)!;
      expect(a.aqi, 101);
      expect(a.level, AqiLevel.sensitive);
      expect(a.severe, isFalse);

      expect(airAlert(150)!.severe, isFalse);
      final b = airAlert(156)!;
      expect(b.level, AqiLevel.unhealthy);
      expect(b.severe, isTrue);
      expect(b, const AirAlert(156));
    });
  });

  for (final (lang, text) in [
    (AppLang.uz, 'Havo ifloslangan (AQI 156) — bugun uyda mashq qiling'),
    (AppLang.ru, 'Воздух загрязнён (AQI 156) — сегодня тренируйтесь дома'),
    (AppLang.en, 'The air is polluted (AQI 156) — work out at home today'),
  ]) {
    testWidgets('warning text (${lang.name})', (tester) async {
      late String got;
      await tester.pumpWidget(
        MaterialApp(
          locale: lang.locale,
          supportedLocales: AppLang.locales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) {
              got = airAlertText(context, const AirAlert(156));
              return const SizedBox();
            },
          ),
        ),
      );
      expect(got, text);
    });
  }
}
