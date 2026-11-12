import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One offline first-aid guide. Texts are `{uz, ru, en}` maps
/// (use `context.trMap`); steps — lists per language.
class FirstAidGuide {
  const FirstAidGuide({
    required this.id,
    required this.emoji,
    required this.title,
    required this.when,
    required this.steps,
  });

  final String id;
  final String emoji;
  final Map<String, dynamic> title;
  final Map<String, dynamic> when;
  final Map<String, List<String>> steps;

  /// Steps in [lang], falling back to Uzbek.
  List<String> stepsFor(String lang) => steps[lang] ?? steps['uz'] ?? const [];

  factory FirstAidGuide.fromMap(Map<String, dynamic> m) => FirstAidGuide(
    id: m['id'] as String,
    emoji: m['emoji'] as String,
    title: Map<String, dynamic>.from(m['title'] as Map),
    when: Map<String, dynamic>.from(m['when'] as Map),
    steps: {
      for (final e in (m['steps'] as Map).entries)
        e.key as String: List<String>.from(e.value as List),
    },
  );
}

/// Bundled with the app — works without internet in both modes, so there
/// is no Supabase table for it.
const firstAidAsset = 'assets/core/first_aid.json';

final firstAidProvider = FutureProvider<List<FirstAidGuide>>((ref) async {
  // cache: false — a cached asset future hangs the next widget test.
  final raw = await rootBundle.loadString(firstAidAsset, cache: false);
  return [
    for (final m in jsonDecode(raw) as List)
      FirstAidGuide.fromMap(m as Map<String, dynamic>),
  ];
});
