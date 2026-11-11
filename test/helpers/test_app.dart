import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/theme/app_theme.dart';

/// Fake-mode prefs (no network). [signedIn] skips onboarding.
Future<SharedPreferences> fakePrefs({bool signedIn = false}) async {
  SharedPreferences.setMockInitialValues({
    if (signedIn) 'core.fake_signed_in': true,
  });
  return SharedPreferences.getInstance();
}

/// Pumps the full app in fake mode.
Future<void> pumpSinoApp(WidgetTester tester, {bool signedIn = false}) async {
  final prefs = await fakePrefs(signedIn: signedIn);
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(prefs: prefs, useFake: true),
      child: const SinoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps a single feature screen in fake mode with Uzbek locale.
Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  final prefs = await fakePrefs(signedIn: true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(prefs: prefs, useFake: true),
      child: MaterialApp(
        theme: AppTheme.light,
        locale: AppLang.uz.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
