// Sprint 2.0 (S2-2): every module C screen (nutrition, workouts, vitals,
// weather) in uz / ru / en × light / dark on a small phone — no layout
// overflow, and no Uzbek UI strings left in ru / en. Kept here, next to the
// other wellness tests; it covers all four C features.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/nutrition/presentation/nutrition_screen.dart';
import 'package:sino/features/vitals/presentation/breathing_screen.dart';
import 'package:sino/features/vitals/presentation/vitals_screen.dart';
import 'package:sino/features/weather/presentation/weather_screen.dart';
import 'package:sino/features/workouts/presentation/workout_player_screen.dart';
import 'package:sino/features/workouts/presentation/workouts_screen.dart';

import '../../helpers/test_app.dart';

final _screens = <String, Widget Function()>{
  'nutrition': () => const NutritionScreen(),
  'workouts': () => const WorkoutsScreen(),
  'workout player': () => const WorkoutPlayerScreen(day: 1),
  'vitals': () => const VitalsScreen(),
  'breathing': () => const BreathingScreen(),
  'weather': () => const WeatherScreen(),
};

/// Uzbek Latin letters o‘ / g‘ (U+2018) — never in Russian or English.
final _uzbek = RegExp('[oOgG]‘');

void main() {
  for (final MapEntry(key: name, value: build) in _screens.entries) {
    for (final lang in AppLang.values) {
      for (final dark in [false, true]) {
        final label = '$name · ${lang.name} · ${dark ? 'dark' : 'light'}';
        testWidgets(label, (tester) async {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final prefs = await fakePrefs(signedIn: true);
          await tester.pumpWidget(
            ProviderScope(
              overrides: appOverrides(prefs: prefs, useFake: true),
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                locale: lang.locale,
                supportedLocales: AppLang.locales,
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: build(),
              ),
            ),
          );
          // The player counts down «get ready» once a second.
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          // Overflow errors fail the test by themselves (with details).

          if (lang != AppLang.uz) {
            final uzbek = [
              for (final t in tester.widgetList<Text>(find.byType(Text)))
                if (_uzbek.hasMatch(t.data ?? t.textSpan?.toPlainText() ?? ''))
                  t.data ?? t.textSpan!.toPlainText(),
            ];
            expect(uzbek, isEmpty, reason: '$label: untranslated');
          }
          // Leave the player's ticker and timers behind.
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
