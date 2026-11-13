import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/core/widgets/progress_ring.dart';
import 'package:sino/features/nutrition/presentation/nutrition_screen.dart';

import '../../helpers/test_app.dart';

/// Palov (osh) from `assets/wellness/foods.json`.
const _palov = (kcal: 600, protein: 18, fat: 30, carbs: 64);

/// What the calorie card shows: eaten kcal, ring value, macro grams + bars.
typedef _Card = ({int eaten, double ring, List<int> macros, List<double> bars});

_Card _readCard(WidgetTester tester) {
  final eatenText = tester.widget<Text>(find.textContaining('Yeyildi: ')).data!;
  final eaten = int.parse(RegExp(r'\d+').firstMatch(eatenText)!.group(0)!);
  final macroRe = RegExp(r'^(\d+) / \d+ g$');
  final macros = [
    for (final t in tester.widgetList<Text>(find.byType(Text)))
      if (t.data != null && macroRe.hasMatch(t.data!))
        int.parse(macroRe.firstMatch(t.data!)!.group(1)!),
  ];
  final bars = [
    for (final b in tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    ))
      b.value!,
  ];
  final ring = tester.widget<ProgressRing>(find.byType(ProgressRing)).value;
  return (eaten: eaten, ring: ring, macros: macros, bars: bars);
}

/// Starts the app screen on [prefs]; a new [UniqueKey] = a fresh
/// ProviderContainer, i.e. an app restart over the same stored data.
Future<void> _start(WidgetTester tester, SharedPreferences prefs) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: appOverrides(prefs: prefs, useFake: true),
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

Finder _palovTile() => find.ancestor(
  of: find.text('Palov (osh)'),
  matching: find.byType(Dismissible),
);

void main() {
  testWidgets('add palov → 1.5 portions → restart → delete → restart: '
      'ring and macro bars follow at once, data survives a restart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final prefs = await fakePrefs(signedIn: true);
    await _start(tester, prefs);
    final base = _readCard(tester);
    expect(base.macros, hasLength(3));
    expect(_palovTile(), findsNothing);

    // 1) Add palov (dinner, 1 portion).
    await tester.tap(find.byKey(const Key('nutrition-add-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nutrition-meal-chip-dinner')));
    await tester.enterText(
      find.byKey(const Key('nutrition-search-field')),
      'palov',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Palov (osh)'));
    await tester.pumpAndSettle();

    final one = _readCard(tester);
    expect(one.eaten, base.eaten + _palov.kcal);
    expect(one.macros, [
      base.macros[0] + _palov.protein,
      base.macros[1] + _palov.fat,
      base.macros[2] + _palov.carbs,
    ]);
    expect(one.ring, greaterThan(base.ring));
    for (var i = 0; i < 3; i++) {
      expect(one.bars[i], greaterThanOrEqualTo(base.bars[i]));
    }

    // 2) Portion 1 → 1.5.
    await tester.tap(
      find.descendant(
        of: _palovTile(),
        matching: find.byTooltip('Porsiyani oshirish'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _palovTile(), matching: find.text('1.5')),
      findsOneWidget,
    );
    final oneHalf = _readCard(tester);
    expect(oneHalf.eaten, base.eaten + 900);
    expect(oneHalf.macros, [
      (base.macros[0] + 27),
      (base.macros[1] + 45),
      (base.macros[2] + 96),
    ]);
    expect(oneHalf.ring, greaterThan(one.ring));

    // 3) Restart: palov ×1.5 is still there, totals unchanged.
    await _start(tester, prefs);
    expect(
      find.descendant(of: _palovTile(), matching: find.text('1.5')),
      findsOneWidget,
    );
    expect(_readCard(tester).eaten, oneHalf.eaten);
    expect(_readCard(tester).macros, oneHalf.macros);

    // 4) Delete (swipe) → back to the start at once.
    await tester.drag(_palovTile(), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(_palovTile(), findsNothing);
    final after = _readCard(tester);
    expect(after.eaten, base.eaten);
    expect(after.macros, base.macros);
    expect(after.ring, closeTo(base.ring, 1e-9));
    for (var i = 0; i < 3; i++) {
      expect(after.bars[i], closeTo(base.bars[i], 1e-9));
    }

    // 5) Restart: the deletion is persisted too.
    await _start(tester, prefs);
    expect(_palovTile(), findsNothing);
    expect(_readCard(tester).eaten, base.eaten);
  });
}
