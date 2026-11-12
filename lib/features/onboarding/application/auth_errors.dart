import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// What went wrong during sign-in, independent of language.
/// The UI turns it into uz/ru/en text (see `authErrorText`).
enum AuthErrorKind {
  invalidCredentials,
  emailNotConfirmed,
  userExists,
  weakPassword,
  invalidEmail,
  rateLimited,
  anonymousDisabled,
  signupDisabled,
  network,
  unknown,
}

AuthErrorKind authErrorKind(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is AuthRetryableFetchException) {
    return AuthErrorKind.network;
  }
  if (error is AuthWeakPasswordException) return AuthErrorKind.weakPassword;
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return AuthErrorKind.invalidCredentials;
      case 'email_not_confirmed':
        return AuthErrorKind.emailNotConfirmed;
      case 'user_already_exists':
      case 'email_exists':
        return AuthErrorKind.userExists;
      case 'weak_password':
        return AuthErrorKind.weakPassword;
      case 'email_address_invalid':
      case 'validation_failed':
        return AuthErrorKind.invalidEmail;
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return AuthErrorKind.rateLimited;
      case 'anonymous_provider_disabled':
        return AuthErrorKind.anonymousDisabled;
      case 'signup_disabled':
      case 'email_provider_disabled':
        return AuthErrorKind.signupDisabled;
    }
    if (error.statusCode == '429') return AuthErrorKind.rateLimited;
  }
  return AuthErrorKind.unknown;
}
