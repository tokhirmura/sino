import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/features/nutrition/data/dasturxon.dart';
import 'package:sino/features/nutrition/presentation/labels.dart';
import 'package:sino/features/nutrition/presentation/nutrition_screen.dart';
import 'package:sino/features/nutrition/presentation/widgets/meal_section.dart';

import '../../helpers/test_app.dart';

/// Builds [fn] with a context in [lang].
Future<T> _inLang<T>(
  WidgetTester tester,
  AppLang lang,
  T Function(BuildContext) fn,
) async {
  late T out;
  await tester.pumpWidget(
    MaterialApp(
      locale: lang.locale,
      supportedLocales: AppLang.locales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (context) {
          out = fn(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return out;
}

int _eaten(WidgetTester tester) {
  final t = tester.widget<Text>(find.textContaining('Yeyildi: ')).data!;
  return int.parse(RegExp(r'\d+').firstMatch(t)!.group(0)!);
}

void main() {
  test('counts and servings as text', () {
    expect(countText(0.5), '½');
    expect(countText(1), '1');
    expect(countText(1.5), '1½');
    expect(countText(3), '3');
    expect(formatServings(1), '1');
    expect(formatServings(1.5), '1.5');
    expect(formatServings(0.25), '0.25');
    expect(formatServings(2.5), '2.5');
  });

  test('every measure has presets', () {
    for (final m in HomeMeasure.values) {
      expect(presetCounts(m), isNotEmpty, reason: m.name);
      expect(presetCounts(m), contains(1), reason: m.name);
    }
  });

  testWidgets('measure names in three languages', (tester) async {
    final uz = await _inLang(
      tester,
      AppLang.uz,
      (c) => [
        measureText(c, HomeMeasure.kosa, 1),
        measureText(c, HomeMeasure.likopcha, 0.5),
        measureText(c, HomeMeasure.dona, 2),
        measureText(c, HomeMeasure.choyQoshiq, 3),
      ],
    );
    expect(uz, ['1 kosa', '½ likopcha', '2 dona', '3 choy qoshiq']);

    final ru = await _inLang(
      tester,
      AppLang.ru,
      (c) => [
        measureText(c, HomeMeasure.kosa, 1),
        measureText(c, HomeMeasure.kosa, 2),
        measureText(c, HomeMeasure.likopcha, 0.5),
        measureText(c, HomeMeasure.piyola, 3),
        measureText(c, HomeMeasure.dona, 4),
      ],
    );
    expect(ru, ['1 миска', '2 миски', '½ тарелки', '3 пиалы', '4 шт.']);

    final en = await _inLang(
      tester,
      AppLang.en,
      (c) => [
        measureText(c, HomeMeasure.kosa, 0.5),
        measureText(c, HomeMeasure.likopcha, 1.5),
        measureText(c, HomeMeasure.dona, 1),
      ],
    );
    expect(en, ['½ bowl', '1½ plates', '1 piece']);
  });

  testWidgets('12 big buttons; «1 likopcha palov» into dinner in two taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pumpScreen(tester, const NutritionScreen());

    for (final i in parseDasturxon(_assetJson)) {
      expect(find.byKey(Key('dasturxon-${i.slug}')), findsOneWidget);
    }
    final before = _eaten(tester);

    await tester.tap(find.byKey(const Key('dasturxon-palov')));
    await tester.pumpAndSettle();
    expect(find.text('1 likopcha'), findsOneWidget);
    expect(find.text('600 kkal'), findsOneWidget);
    expect(find.text('½ likopcha'), findsOneWidget);
    expect(find.text('300 kkal'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dasturxon-meal-dinner')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dasturxon-add-likopcha-1')));
    await tester.pumpAndSettle();

    expect(_eaten(tester), before + 600);
    expect(
      find.text('Palov (osh) — 1 likopcha · Kechki ovqat'),
      findsOneWidget,
    );
    final dinner = find.byWidgetPredicate(
      (w) => w is MealSection && w.meal.name == 'dinner',
    );
    expect(
      find.descendant(of: dinner, matching: find.text('Palov (osh)')),
      findsOneWidget,
    );
  });

  testWidgets('2 dona manti = half a catalog portion (4 dona)', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pumpScreen(tester, const NutritionScreen());
    final before = _eaten(tester);

    await tester.tap(find.byKey(const Key('dasturxon-manti')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dasturxon-add-dona-2')));
    await tester.pumpAndSettle();
    expect(_eaten(tester), before + 250); // 500 kkal × 0.5
  });
}

final _assetJson = File(dasturxonAsset).readAsStringSync();
