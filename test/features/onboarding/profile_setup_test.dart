import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/backend/backend.dart';
import 'package:sino/core/data/user.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/features/onboarding/application/onboarding_prefs.dart';
import 'package:sino/features/onboarding/application/setup_prefill.dart';

/// Full app in fake mode with the given stored prefs.
Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  Map<String, Object> prefsValues,
) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(prefs: prefs, useFake: true),
      child: const SinoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SinoApp)));
}

String _profileJson(UserProfile p) => jsonEncode(p.toMap());

/// Signed in (fake) with an empty profile → questionnaire.
Map<String, Object> _emptyProfileSession({SetupPrefill? prefill}) => {
  PrefKeys.fakeSignedIn: true,
  IntroSeenNotifier.key: true,
  PrefKeys.fakeProfile: _profileJson(
    const UserProfile(id: 'fake-user', fullName: ''),
  ),
  if (prefill != null) SetupPrefillNotifier.key: jsonEncode(prefill.toMap()),
};

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('UserProfile.isComplete needs name, birth year, height, weight', () {
    const empty = UserProfile(id: 'x', fullName: '');
    expect(empty.isComplete, isFalse);
    expect(
      empty
          .copyWith(fullName: 'Aziz', birthYear: 1997, heightCm: 178)
          .isComplete,
      isFalse,
    );
    expect(
      empty
          .copyWith(
            fullName: 'Aziz',
            birthYear: 1997,
            heightCm: 178,
            weightKg: 76,
          )
          .isComplete,
      isTrue,
    );
    expect(UserProfile.fake.isComplete, isTrue);
  });

  testWidgets('complete profile → home, no questionnaire', (tester) async {
    await _pumpApp(tester, {PrefKeys.fakeSignedIn: true});
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Profilingiz'), findsNothing);
  });

  testWidgets('empty profile survives restart → questionnaire', (tester) async {
    await _pumpApp(tester, _emptyProfileSession());
    expect(find.text('Profilingiz'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('questionnaire: validation errors', (tester) async {
    await _pumpApp(tester, _emptyProfileSession());
    await _tap(tester, find.widgetWithText(FilledButton, 'Saqlash'));

    expect(find.text('Ismingizni kiriting'), findsOneWidget);
    expect(find.textContaining('oralig‘idagi yil'), findsOneWidget);
    expect(find.text('50–250 sm'), findsOneWidget);
    expect(find.text('20–300 kg'), findsOneWidget);

    await tester.enterText(_field('Tug‘ilgan yil'), '1850');
    await _tap(tester, find.widgetWithText(FilledButton, 'Saqlash'));
    expect(find.textContaining('oralig‘idagi yil'), findsOneWidget);
    expect(find.text('Profilingiz'), findsOneWidget);
  });

  testWidgets('questionnaire: save → profile stored → home greets by name', (
    tester,
  ) async {
    final container = await _pumpApp(tester, _emptyProfileSession());

    await tester.enterText(_field('Ism'), 'Madina');
    await tester.enterText(_field('Tug‘ilgan yil'), '1999');
    await tester.enterText(_field('Bo‘y'), '165');
    await tester.enterText(_field('Vazn'), '58,5');
    await _tap(tester, find.widgetWithText(FilledButton, 'Saqlash'));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Salom, Madina'), findsOneWidget);

    final saved = container.read(fakeProfileProvider);
    expect(saved.fullName, 'Madina');
    expect(saved.birthYear, 1999);
    expect(saved.heightCm, 165);
    expect(saved.weightKg, 58.5);
    expect(saved.isComplete, isTrue);
    final raw = container
        .read(sharedPreferencesProvider)
        .getString(PrefKeys.fakeProfile);
    expect(raw, contains('Madina'));
  });

  testWidgets('questionnaire: prefill shown, cleared after save', (
    tester,
  ) async {
    final container = await _pumpApp(
      tester,
      _emptyProfileSession(
        prefill: const SetupPrefill(fullName: 'Aziz Karimov', birthYear: 1997),
      ),
    );
    expect(_field('Aziz Karimov'), findsOneWidget);
    expect(_field('1997'), findsOneWidget);

    await tester.enterText(_field('Bo‘y'), '178');
    await tester.enterText(_field('Vazn'), '76');
    await _tap(tester, find.widgetWithText(FilledButton, 'Saqlash'));

    expect(find.text('Salom, Aziz Karimov'), findsOneWidget);
    expect(container.read(setupPrefillProvider), isNull);
  });

  testWidgets('questionnaire: sign out → onboarding', (tester) async {
    final container = await _pumpApp(tester, _emptyProfileSession());
    await _tap(tester, find.text('Chiqish'));
    expect(container.read(fakeAuthProvider), isFalse);
    expect(find.text('Kirish usulini tanlang'), findsOneWidget);
  });
}
