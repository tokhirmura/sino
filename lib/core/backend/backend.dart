import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/prefs.dart';

/// Supabase bootstrap. Keys come only from `--dart-define-from-file=env.json`.
///
/// Fake mode (no network, data from `assets/<module>/`) is on when
/// `USE_FAKE=true`, when keys are missing, or when init failed.
abstract final class Backend {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const forceFake = bool.fromEnvironment('USE_FAKE');

  static bool _ready = false;

  /// True when Supabase was successfully initialized.
  static bool get isReady => _ready;

  static Future<void> init() async {
    if (forceFake || supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      debugPrint('[Backend] fake mode (USE_FAKE or keys missing)');
      return;
    }
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _ready = true;
    } catch (e, st) {
      debugPrint('[Backend] Supabase init failed, fake mode: $e\n$st');
    }
  }
}

/// `true` → repositories must use their Fake implementation.
final useFakeProvider = Provider<bool>((ref) => !Backend.isReady);

/// The only way features access Supabase. Never call `Supabase.initialize`
/// in features. Throws in fake mode — check [useFakeProvider] first.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (ref.watch(useFakeProvider)) {
    throw StateError('Supabase is not available in fake mode');
  }
  return Supabase.instance.client;
});

/// Stream of the current Supabase session (null = signed out).
/// In fake mode emits a single `null`; use [isSignedInProvider] for routing.
final authStateProvider = StreamProvider<Session?>((ref) async* {
  if (ref.watch(useFakeProvider)) {
    yield null;
    return;
  }
  final auth = ref.watch(supabaseClientProvider).auth;
  yield auth.currentSession;
  yield* auth.onAuthStateChange.map((event) => event.session);
});

/// Fake-mode "session": a flag in SharedPreferences.
class FakeAuthNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(PrefKeys.fakeSignedIn) ??
      false;

  Future<void> signIn() async {
    state = true;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.fakeSignedIn, true);
  }

  Future<void> signOut() async {
    state = false;
    await ref.read(sharedPreferencesProvider).remove(PrefKeys.fakeSignedIn);
  }
}

final fakeAuthProvider = NotifierProvider<FakeAuthNotifier, bool>(
  FakeAuthNotifier.new,
);

/// Unified "is the user signed in" for both modes. The router listens to it.
final isSignedInProvider = Provider<bool>((ref) {
  if (ref.watch(useFakeProvider)) return ref.watch(fakeAuthProvider);
  final session = ref.watch(authStateProvider).value;
  return (session ?? ref.watch(supabaseClientProvider).auth.currentSession) !=
      null;
});

/// Signs out in either mode.
Future<void> signOut(WidgetRef ref) async {
  if (ref.read(useFakeProvider)) {
    await ref.read(fakeAuthProvider.notifier).signOut();
  } else {
    await ref.read(supabaseClientProvider).auth.signOut();
  }
}
