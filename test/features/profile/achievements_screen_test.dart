import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/profile/presentation/achievements_screen.dart';
import 'package:sino/features/profile/profile_feature.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  SharedPreferences.setMockInitialValues({
    'core.fake_signed_in': true,
    PrefKeys.fakeAchievements: jsonEncode({
      'first_workout': '2026-11-15T18:40:00.000',
      'steps_10k': '2026-11-19T21:00:00.000',
    }),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(prefs: prefs, useFake: true),
      child: MaterialApp(
        theme: AppTheme.light,
        locale: AppLang.uz.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('profile registers /profile/achievements', () {
    final root = profileRoutes.whereType<GoRoute>().single;
    expect(
      root.routes.whereType<GoRoute>().map((r) => '${root.path}/${r.path}'),
      contains(AppRoutes.achievements),
    );
  });

  testWidgets('8 badges: unlocked with dates, locked explain how', (
    tester,
  ) async {
    await _pump(tester, const AchievementsScreen());

    expect(find.byKey(const ValueKey('badges-count')), findsOneWidget);
    expect(find.text('2/8'), findsOneWidget);
    expect(find.text('2 / 8 ochildi'), findsOneWidget);
    expect(find.byType(InkWell).evaluate().length, greaterThanOrEqualTo(8));
    for (final code in [
      'first_workout',
      'water_7',
      'meds_3',
      'first_reservation',
      'steps_10k',
      'index_90',
      'streak_7',
      'full_day',
    ]) {
      expect(find.byKey(ValueKey('badge-$code')), findsOneWidget, reason: code);
    }
    // Newest unlocked first.
    final first = tester.getTopLeft(
      find.byKey(const ValueKey('badge-steps_10k')),
    );
    final second = tester.getTopLeft(
      find.byKey(const ValueKey('badge-first_workout')),
    );
    expect(first.dx < second.dx || first.dy < second.dy, isTrue);

    await tester.tap(find.byKey(const ValueKey('badge-water_7')));
    await tester.pumpAndSettle();
    expect(
      find.text('7 kun ketma-ket kuniga 8 stakan suv iching'),
      findsOneWidget,
    );
    expect(find.text('Hali ochilmagan'), findsOneWidget);
  });
}
