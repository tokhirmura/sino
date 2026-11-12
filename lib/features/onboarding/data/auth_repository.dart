import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';

/// Outcome of an email sign-up.
enum SignUpResult {
  /// Session created — the router moves the user to home.
  signedIn,

  /// Project requires email confirmation — no session yet.
  confirmEmail,
}

/// Sign-in paths of the onboarding. The router reacts to the new session
/// through `isSignedInProvider`, so callers never navigate themselves.
abstract class AuthRepository {
  /// Anonymous session (guest and, for now, OneID).
  Future<void> signInAnonymously({required String lang});

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  /// [lang] goes to user metadata → `profiles.lang` (DB trigger).
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String lang,
  });
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  Future<void> signInAnonymously({required String lang}) async {
    await _auth.signInAnonymously(data: {'lang': lang});
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
  }

  @override
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String lang,
  }) async {
    final res = await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'lang': lang},
    );
    return res.session == null
        ? SignUpResult.confirmEmail
        : SignUpResult.signedIn;
  }
}

/// Offline: every path just sets the fake session flag.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._setSignedIn);

  final Future<void> Function() _setSignedIn;

  @override
  Future<void> signInAnonymously({required String lang}) => _setSignedIn();

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _setSignedIn();

  @override
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String lang,
  }) async {
    await _setSignedIn();
    return SignUpResult.signedIn;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeAuthRepository(() => ref.read(fakeAuthProvider.notifier).signIn())
      : SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);
