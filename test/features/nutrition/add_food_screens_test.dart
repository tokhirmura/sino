// The new «add food» ways (sheet, photo, homemade, barcode) in uz / ru / en
// × light / dark on a small phone: no overflow, no Uzbek strings left in
// ru / en, examples read fully in every language.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/nutrition/data/food_vision.dart';
import 'package:sino/features/nutrition/data/models.dart';
import 'package:sino/features/nutrition/presentation/barcode_food_screen.dart';
import 'package:sino/features/nutrition/presentation/nutrition_screen.dart';
import 'package:sino/features/nutrition/presentation/photo_food_screen.dart';
import 'package:sino/features/nutrition/presentation/recipe_screen.dart';

import '../../helpers/test_app.dart';

/// Uzbek Latin letters o‘ / g‘ (U+2018) — never in Russian or English.
final _uzbek = RegExp('[oOgG]‘');

class _FakePicker implements FoodPhotoPicker {
  @override
  Future<Uint8List?> pick(FoodPhotoSource source) async =>
      Uint8List.fromList(List.generate(900, (i) => i % 251));
}

/// Screen + what to do on it before checking.
final _cases = <String, (Widget, Future<void> Function(WidgetTester))>{
  'add sheet': (
    const NutritionScreen(),
    (t) async {
      await t.tap(find.byKey(const Key('nutrition-add-fab')));
      await t.pumpAndSettle();
    },
  ),
  'photo intro': (const PhotoFoodScreen(meal: Meal.lunch), (_) async {}),
  'photo result': (
    const PhotoFoodScreen(meal: Meal.lunch),
    (t) async {
      await t.tap(find.byKey(const Key('nutrition-photo-camera')));
      await t.pumpAndSettle();
    },
  ),
  'recipe example': (
    const RecipeScreen(meal: Meal.dinner),
    (t) async {
      for (final ex in ['palov', 'omlet', 'salat']) {
        await t.tap(find.byKey(Key('nutrition-recipe-example-$ex')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('nutrition-recipe-lines')), findsOneWidget);
        expect(
          find.byKey(const Key('nutrition-recipe-unknown')),
          findsNothing,
          reason: ex,
        );
        await t.enterText(find.byKey(const Key('nutrition-recipe-text')), '');
        await t.pumpAndSettle();
      }
      await t.tap(find.byKey(const Key('nutrition-recipe-example-palov')));
      await t.pumpAndSettle();
    },
  ),
  'barcode list': (
    const BarcodeFoodScreen(meal: Meal.snack, useCamera: false),
    (_) async {},
  ),
  'barcode product': (
    const BarcodeFoodScreen(meal: Meal.snack, useCamera: false),
    (t) async {
      final rollton = find.byKey(const Key('nutrition-product-rollton'));
      await t.ensureVisible(rollton);
      await t.pumpAndSettle();
      await t.tap(rollton);
      await t.pumpAndSettle();
    },
  ),
};

void main() {
  for (final MapEntry(key: name, value: (screen, act)) in _cases.entries) {
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
              overrides: [
                ...appOverrides(prefs: prefs, useFake: true),
                foodPhotoPickerProvider.overrideWithValue(_FakePicker()),
              ],
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
          await act(tester);
          // Overflow errors fail the test by themselves (with details).

          if (lang != AppLang.uz) {
            final uzbek = [
              for (final t in tester.widgetList<Text>(find.byType(Text)))
                if (_uzbek.hasMatch(t.data ?? t.textSpan?.toPlainText() ?? ''))
                  t.data ?? t.textSpan!.toPlainText(),
            ];
            expect(uzbek, isEmpty, reason: '$label: untranslated');
          }
        });
      }
    }
  }
}
