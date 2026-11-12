import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';
import '../../../core/data/user.dart';

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

/// Offline: every path sets the fake session flag. Like a brand-new
/// account, the fake profile starts empty → the questionnaire shows.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._signIn);

  final Future<void> Function(String lang) _signIn;

  @override
  Future<void> signInAnonymously({required String lang}) => _signIn(lang);

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _signIn('uz');

  @override
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String lang,
  }) async {
    await _signIn(lang);
    return SignUpResult.signedIn;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeAuthRepository((lang) async {
          // Profile first, so the router goes straight to the questionnaire.
          await ref.read(fakeProfileProvider.notifier).startEmpty(lang: lang);
          await ref.read(fakeAuthProvider.notifier).signIn();
        })
      : SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);
