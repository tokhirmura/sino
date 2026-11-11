import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs.dart';

enum AppLang {
  uz,
  ru,
  en;

  Locale get locale => Locale(name);

  String get label => switch (this) {
    AppLang.uz => 'O‘zbekcha',
    AppLang.ru => 'Русский',
    AppLang.en => 'English',
  };

  static List<Locale> get locales => [for (final l in values) l.locale];

  static AppLang fromCode(String? code) =>
      values.firstWhere((l) => l.name == code, orElse: () => AppLang.uz);
}

class AppLangNotifier extends Notifier<AppLang> {
  @override
  AppLang build() => AppLang.fromCode(
    ref.watch(sharedPreferencesProvider).getString(PrefKeys.lang),
  );

  Future<void> set(AppLang lang) async {
    state = lang;
    await ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.lang, lang.name);
  }
}

/// Current UI language; default uz, persisted in SharedPreferences.
final appLangProvider = NotifierProvider<AppLangNotifier, AppLang>(
  AppLangNotifier.new,
);

extension AppLangContext on BuildContext {
  /// Current language from the app Locale (rebuilds on change).
  AppLang get lang =>
      AppLang.fromCode(Localizations.maybeLocaleOf(this)?.languageCode);

  /// All UI strings go through this. Uzbek (Latin) is mandatory.
  String tr({required String uz, String? ru, String? en}) => switch (lang) {
    AppLang.uz => uz,
    AppLang.ru => ru ?? uz,
    AppLang.en => en ?? uz,
  };

  /// Picks a value from a `{uz, ru, en}` jsonb map (DB / assets).
  String trMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return '';
    return (map[lang.name] ?? map['uz'] ?? map.values.first).toString();
  }
}
