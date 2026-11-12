import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences instance. `main.dart` overrides it after
/// `SharedPreferences.getInstance()`; tests override it with mock values.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  ),
);

/// Keys used by lib/core. Features should prefix their own keys with
/// the feature name, e.g. `pharmacy.recent_queries`.
abstract final class PrefKeys {
  static const lang = 'core.lang';
  static const fakeSignedIn = 'core.fake_signed_in';
  static const fakeProfile = 'core.fake_profile';
  static const fakeFamily = 'core.fake_family';
  static const theme = 'core.theme';
}
