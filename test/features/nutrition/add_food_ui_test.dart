import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/nutrition/data/food_vision.dart';
import 'package:sino/features/nutrition/presentation/nutrition_screen.dart';
import 'package:sino/features/nutrition/presentation/widgets/meal_section.dart';

import '../../helpers/test_app.dart';

/// A dish in the day's meals.
Finder _inDiary(String name) => find.descendant(
  of: find.byType(MealSection),
  matching: find.textContaining(name),
);

class _FakePicker implements FoodPhotoPicker {
  @override
  Future<Uint8List?> pick(FoodPhotoSource source) async =>
      Uint8List.fromList(List.generate(2000, (i) => (i * 7) % 256));
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final prefs = await fakePrefs(signedIn: true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appOverrides(prefs: prefs, useFake: true),
        foodPhotoPickerProvider.overrideWithValue(_FakePicker()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: AppLang.uz.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const NutritionScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openMode(WidgetTester tester, String mode) async {
  await tester.tap(find.byKey(const Key('nutrition-add-fab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('nutrition-mode-$mode')));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sheet: four ways to add + recently eaten', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('nutrition-add-fab')));
    await tester.pumpAndSettle();
    for (final m in ['photo', 'recipe', 'barcode', 'quick']) {
      expect(find.byKey(Key('nutrition-mode-$m')), findsOneWidget);
    }
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('Yaqinda yeganlaringiz'), findsOneWidget);
    expect(find.byKey(const Key('nutrition-recent-0')), findsOneWidget);

    // Searching hides them — the list needs the room.
    await tester.enterText(
      find.byKey(const Key('nutrition-search-field')),
      'palov',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nutrition-mode-photo')), findsNothing);
    expect(find.text('Yaqinda yeganlaringiz'), findsNothing);
  });

  testWidgets('just calories → in the diary with a confirmation', (
    tester,
  ) async {
    await _pump(tester);
    await _openMode(tester, 'quick');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('nutrition-quick-save')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('nutrition-quick-name')),
      'Kafedagi burger',
    );
    await tester.enterText(
      find.byKey(const Key('nutrition-quick-kcal')),
      '650',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('nutrition-quick-save')));
    await tester.pumpAndSettle();

    expect(_inDiary('Kafedagi burger'), findsOneWidget);
    expect(find.textContaining('Kafedagi burger · 650 kkal'), findsOneWidget);
  });

  testWidgets('homemade: example palov → per portion → diary, saved', (
    tester,
  ) async {
    await _pump(tester);
    await _openMode(tester, 'recipe');
    expect(find.text('O‘zim pishirdim'), findsOneWidget);
    final add = find.byKey(const Key('nutrition-recipe-add'));

    await tester.tap(find.byKey(const Key('nutrition-recipe-example-palov')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nutrition-recipe-lines')), findsOneWidget);
    expect(find.text('Guruch'), findsOneWidget);
    expect(find.text('Qo‘y go‘shti'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('nutrition-recipe-portions')))
          .data,
      '6',
    );
    expect(find.byKey(const Key('nutrition-recipe-portion')), findsOneWidget);

    // 6 → 5 portions: each portion gets bigger.
    String portion() => tester
        .widget<Text>(find.byKey(const Key('nutrition-recipe-portion')))
        .data!;
    final six = portion();
    await _tapVisible(
      tester,
      find.byKey(const Key('nutrition-recipe-portions-minus')),
    );
    expect(portion(), isNot(six));

    await _tapVisible(tester, add);
    expect(_inDiary('Uy palovi'), findsOneWidget);
    expect(find.textContaining('Uy palovi ·'), findsWidgets);

    // Saved: next time it is one tap away.
    await _openMode(tester, 'recipe');
    expect(
      find.byKey(const Key('nutrition-my-recipe-Uy palovi')),
      findsOneWidget,
    );
  });

  testWidgets('homemade: unknown words are shown, not silently dropped', (
    tester,
  ) async {
    await _pump(tester);
    await _openMode(tester, 'recipe');
    await tester.enterText(
      find.byKey(const Key('nutrition-recipe-text')),
      'tuxum 3 ta, sariyog‘ 10 g, qandaydir sous',
    );
    await tester.pumpAndSettle();
    expect(find.text('Tuxum'), findsOneWidget);
    expect(find.text('Sariyog‘'), findsOneWidget);
    expect(find.byKey(const Key('nutrition-recipe-unknown')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('nutrition-recipe-unknown')),
        matching: find.textContaining('qandaydir sous'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('barcode: typed code → label with flags → 100 g → diary', (
    tester,
  ) async {
    await _pump(tester);
    await _openMode(tester, 'barcode');
    await tester.tap(find.byKey(const Key('nutrition-barcode-type')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('nutrition-barcode-field')),
      '3017620422003',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('nutrition-barcode-find')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nutrition-product-view')), findsOneWidget);
    expect(find.text('Nutella'), findsOneWidget);
    expect(find.byKey(const Key('nutrition-flag-sugar')), findsOneWidget);
    expect(find.byKey(const Key('nutrition-flag-fat')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nutrition-product-amount-100')));
    await tester.pumpAndSettle();
    expect(find.text('Qo‘shish · 539 kkal'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('nutrition-product-add')));
    expect(_inDiary('Nutella'), findsOneWidget);
  });

  testWidgets('barcode: popular product, a whole pack', (tester) async {
    await _pump(tester);
    await _openMode(tester, 'barcode');
    await tester.enterText(
      find.byKey(const Key('nutrition-product-search')),
      'rollton',
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('nutrition-product-rollton')),
    );
    expect(find.byKey(const Key('nutrition-flag-salt')), findsOneWidget);
    // Default amount: one pack (60 g of 449 kcal / 100 g).
    expect(find.text('Qo‘shish · 269 kkal'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('nutrition-product-add')));
    expect(_inDiary('Rollton'), findsOneWidget);
  });

  testWidgets('barcode: unknown code → typed from the label → remembered', (
    tester,
  ) async {
    await _pump(tester);
    await _openMode(tester, 'barcode');
    await tester.tap(find.byKey(const Key('nutrition-barcode-type')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('nutrition-barcode-field')),
      '4780000000001',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('nutrition-barcode-find')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('nutrition-barcode-not-found')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('nutrition-barcode-enter-label')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('nutrition-label-name')),
      'Qurt',
    );
    await tester.enterText(
      find.byKey(const Key('nutrition-label-kcal')),
      '300',
    );
    await tester.enterText(find.byKey(const Key('nutrition-label-pack')), '50');
    await tester.pump();
    await tester.tap(find.byKey(const Key('nutrition-label-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nutrition-product-view')), findsOneWidget);
    expect(find.text('Siz kiritgansiz'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('nutrition-product-add')));
    expect(_inDiary('Qurt'), findsOneWidget);

    // Same code again: known now.
    await _openMode(tester, 'barcode');
    await tester.tap(find.byKey(const Key('nutrition-barcode-type')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('nutrition-barcode-field')),
      '4780000000001',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('nutrition-barcode-find')));
    await tester.pumpAndSettle();
    expect(find.text('Qurt'), findsOneWidget);
  });

  testWidgets('photo (demo offline): 3 guesses → pick, grams → diary', (
    tester,
  ) async {
    await _pump(tester);
    await _openMode(tester, 'photo');
    await tester.tap(find.byKey(const Key('nutrition-photo-camera')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Demo-taxmin'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(Key('nutrition-photo-guess-$i')), findsOneWidget);
    }
    expect(find.text('62%'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nutrition-photo-guess-1')));
    await tester.pumpAndSettle();
    final title = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('nutrition-photo-guess-1')),
            matching: find.byType(Text),
          ),
        )
        .first
        .data!;
    await _tapVisible(tester, find.byKey(const Key('nutrition-photo-add')));
    expect(_inDiary(title), findsWidgets);
  });

  testWidgets('like yesterday: an empty meal repeats the previous day', (
    tester,
  ) async {
    await _pump(tester);
    // Demo: today has no dinner, yesterday's dinner was shurpa.
    final repeat = find.byKey(const Key('nutrition-repeat-dinner'));
    expect(repeat, findsOneWidget);
    expect(find.byKey(const Key('nutrition-repeat-breakfast')), findsNothing);
    expect(_inDiary('Sho‘rva'), findsNothing);
    await _tapVisible(tester, repeat);
    expect(_inDiary('Sho‘rva'), findsOneWidget);
    expect(repeat, findsNothing);
    expect(find.text('Kechki ovqat: 1 ta taom qo‘shildi'), findsOneWidget);
  });
}
