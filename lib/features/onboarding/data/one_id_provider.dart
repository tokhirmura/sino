import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

/// Identity data "pulled" from OneID (state registry).
class OneIdProfile {
  const OneIdProfile({
    required this.fullName,
    required this.pinflMasked,
    required this.birthDate,
    required this.polyclinic,
    required this.medicalRecords,
    required this.prescriptions,
    required this.insurance,
  });

  final String fullName;
  final String pinflMasked;
  final DateTime birthDate;

  /// `{uz, ru, en}` — show via `context.trMap`.
  final Map<String, dynamic> polyclinic;
  final int medicalRecords;
  final int prescriptions;

  /// `{uz, ru, en}` — show via `context.trMap`.
  final Map<String, dynamic> insurance;

  factory OneIdProfile.fromMap(Map<String, dynamic> m) => OneIdProfile(
    fullName: m['full_name'] as String,
    pinflMasked: m['pinfl'] as String,
    birthDate: DateTime.parse(m['birth_date'] as String),
    polyclinic: Map<String, dynamic>.from(m['polyclinic'] as Map),
    medicalRecords: m['medical_records'] as int,
    prescriptions: m['prescriptions'] as int,
    insurance: Map<String, dynamic>.from(m['insurance'] as Map),
  );
}

/// The ONLY place that knows how OneID works.
///
/// OneID is not a Supabase Auth provider yet, so today:
/// - [verify] imitates biometrics (~2 s) and returns mock registry data
///   from `assets/core/oneid_mock.json`;
/// - [signIn] opens a real anonymous Supabase session (flag in fake mode).
///
/// To plug in real OneID (OIDC), replace this class only — the UI and the
/// router stay the same.
class OneIdAuthProvider {
  OneIdAuthProvider(
    this._auth, {
    this.scanDuration = const Duration(seconds: 2),
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  final AuthRepository _auth;
  final AssetBundle _bundle;
  final Duration scanDuration;

  static const _mockAsset = 'assets/core/oneid_mock.json';

  Future<OneIdProfile> verify() async {
    final results = await Future.wait([
      Future<void>.delayed(scanDuration),
      _bundle.loadString(_mockAsset, cache: false),
    ]);
    final json = jsonDecode(results[1] as String) as Map<String, dynamic>;
    return OneIdProfile.fromMap(json);
  }

  /// Call only after the user agreed to medical-card access: the new
  /// session immediately sends the router to home.
  Future<void> signIn({required String lang}) =>
      _auth.signInAnonymously(lang: lang);
}

final oneIdAuthProvider = Provider<OneIdAuthProvider>(
  (ref) => OneIdAuthProvider(ref.watch(authRepositoryProvider)),
);
