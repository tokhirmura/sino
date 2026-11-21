import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/app/feature_registry.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/core/widgets/money.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('no session → onboarding → home with tabs and cards', (
    tester,
  ) async {
    await pumpSinoApp(tester);
    expect(find.text('Sog‘lig‘ingiz — bitta ilovada'), findsOneWidget);

    await tester.tap(find.text('O‘tkazib yuborish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mehmon sifatida davom etish'));
    await tester.pumpAndSettle();

    // First run: empty profile → main goal → questionnaire.
    expect(find.text('Profilingiz'), findsOneWidget);
    expect(find.text('Asosiy maqsadingiz nima?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goal-energy')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Davom etish'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Davom etish'));
    await tester.pumpAndSettle();
    final field = find.byType(TextFormField);
    await tester.enterText(field.at(0), 'Aziz');
    await tester.enterText(field.at(1), '1997');
    await tester.enterText(field.at(2), '178');
    await tester.enterText(field.at(3), '76');
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Xayrli (tong|kun|kech), Aziz$')),
      findsOneWidget,
    );
    expect(find.text('Dorixona'), findsWidgets);
  });

  testWidgets('signed-in fake session starts on home', (tester) async {
    await pumpSinoApp(tester, signedIn: true);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('tabs switch', (tester) async {
    await pumpSinoApp(tester, signedIn: true);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Elektron tibbiy karta'), findsOneWidget);
  });

  test('registry: home cards sorted, routes registered', () {
    final orders = [for (final c in allHomeCards) c.order];
    expect(orders, [...orders]..sort());
    expect(tabBranchRoutes, hasLength(5));
    expect(allRoutes, hasLength(14));
    expect([
      for (final r in allRoutes.whereType<GoRoute>()) r.path,
    ], contains(AppRoutes.report));
  });

  test('text on brand buttons is readable in both themes (WCAG AA)', () {
    double contrast(Color a, Color b) {
      final l1 = a.computeLuminance(), l2 = b.computeLuminance();
      return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
    }

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final s = theme.colorScheme;
      expect(contrast(s.primary, s.onPrimary), greaterThanOrEqualTo(4.5));
      expect(contrast(s.error, s.onError), greaterThanOrEqualTo(3));
    }
  });

  test('money format', () {
    expect(formatMoney(11500), '11 500 so‘m');
    expect(formatMoney(950), '950 so‘m');
  });
}
