// Lead-only file.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/backend/backend.dart';
import '../core/contracts/home_card.dart';
import '../core/l10n/app_lang.dart';
import '../core/storage/prefs.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode.dart';
import 'feature_registry.dart';
import 'router.dart';

/// Overrides shared by main.dart and tests.
/// Pass [useFake] = true in tests to guarantee no network.
List<Override> appOverrides({
  required SharedPreferences prefs,
  bool? useFake,
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  homeCardsProvider.overrideWithValue(allHomeCards),
  if (useFake != null) useFakeProvider.overrideWithValue(useFake),
];

class SinoApp extends ConsumerWidget {
  const SinoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final lang = ref.watch(appLangProvider);
    return MaterialApp.router(
      title: 'Sino',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      locale: lang.locale,
      supportedLocales: AppLang.locales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    );
  }
}
