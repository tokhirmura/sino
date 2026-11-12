import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/app/feature_registry.dart';
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

    // First run: empty profile → questionnaire.
    expect(find.text('Profilingiz'), findsOneWidget);
    final field = find.byType(TextFormField);
    await tester.enterText(field.at(0), 'Aziz');
    await tester.enterText(field.at(1), '1997');
    await tester.enterText(field.at(2), '178');
    await tester.enterText(field.at(3), '76');
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Salom, Aziz'), findsOneWidget);
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
    expect(allRoutes, hasLength(13));
  });

  test('text on brand buttons is white in both themes', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(theme.colorScheme.onPrimary, Colors.white);
    }
  });

  test('money format', () {
    expect(formatMoney(11500), '11 500 so‘m');
    expect(formatMoney(950), '950 so‘m');
  });
}
