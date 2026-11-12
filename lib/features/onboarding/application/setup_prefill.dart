import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/prefs.dart';

/// Values to pre-fill the questionnaire with (e.g. from OneID).
class SetupPrefill {
  const SetupPrefill({this.fullName, this.birthYear});

  final String? fullName;
  final int? birthYear;

  Map<String, dynamic> toMap() => {
    'full_name': fullName,
    'birth_year': birthYear,
  };

  factory SetupPrefill.fromMap(Map<String, dynamic> m) => SetupPrefill(
    fullName: m['full_name'] as String?,
    birthYear: m['birth_year'] as int?,
  );
}

/// Survives the sign-in → questionnaire hop (different routes / restarts).
class SetupPrefillNotifier extends Notifier<SetupPrefill?> {
  static const key = 'onboarding.setup_prefill';

  @override
  SetupPrefill? build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(key);
    if (raw == null) return null;
    try {
      return SetupPrefill.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> set(SetupPrefill prefill) async {
    state = prefill;
    await ref
        .read(sharedPreferencesProvider)
        .setString(key, jsonEncode(prefill.toMap()));
  }

  Future<void> clear() async {
    state = null;
    await ref.read(sharedPreferencesProvider).remove(key);
  }
}

final setupPrefillProvider =
    NotifierProvider<SetupPrefillNotifier, SetupPrefill?>(
      SetupPrefillNotifier.new,
    );
