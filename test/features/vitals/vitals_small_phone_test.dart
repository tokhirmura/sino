import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/vitals/presentation/breathing_screen.dart';
import 'package:sino/features/vitals/presentation/vitals_screen.dart';

/// Small phone (360×640), 3 languages × 2 themes: no overflow, «Start» reachable.
void main() {
  for (final dark in [false, true]) {
    for (final lang in AppLang.values) {
      for (final (name, screen) in [
        ('breath', const BreathingScreen()),
        ('vitals', const VitalsScreen()),
      ]) {
        testWidgets('$name ${lang.name} dark=$dark 360x640', (tester) async {
          tester.view.physicalSize = const Size(720, 1280);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          SharedPreferences.setMockInitialValues({
            'core.fake_signed_in': true,
            'core.lang': lang.name,
          });
          final prefs = await SharedPreferences.getInstance();
          await tester.pumpWidget(
            ProviderScope(
              overrides: appOverrides(prefs: prefs, useFake: true),
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                locale: lang.locale,
                supportedLocales: AppLang.locales,
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: screen,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (name == 'breath') {
            await tester.tap(find.byKey(const Key('breath-start')));
            await tester.pump(const Duration(seconds: 5));
            expect(tester.takeException(), isNull);
            await tester.pump(const Duration(seconds: 7));
            expect(tester.takeException(), isNull);
            await tester.tap(find.byKey(const Key('breath-stop')));
            await tester.pumpAndSettle();
          }
          if (name == 'vitals') {
            await tester.tap(find.byKey(const Key('vitals-tile-steps')));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('vitals-tile-pressure')));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('vitals-add-fab')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }
}
