import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a reply button does.
enum ActionType { pharmacy, open, call }

class AssistantAction {
  const AssistantAction({
    required this.type,
    this.route,
    this.query,
    this.number,
  });

  final ActionType type;

  /// [ActionType.open]: an `AppRoutes` path.
  final String? route;

  /// [ActionType.pharmacy]: search query for `/pharmacy?q=`.
  final String? query;

  /// [ActionType.call]: phone number.
  final String? number;

  factory AssistantAction.fromMap(Map<String, dynamic> m) => AssistantAction(
    type: ActionType.values.byName(m['type'] as String),
    route: m['route'] as String?,
    query: m['query'] as String?,
    number: m['number'] as String?,
  );
}

/// One topic: keywords in uz/ru/en and a localized answer.
class AssistantRule {
  const AssistantRule({
    required this.id,
    required this.redFlag,
    required this.keywords,
    required this.title,
    required this.answer,
    required this.actions,
  });

  final String id;

  /// Emergency topic → «103 ga qo‘ng‘iroq qiling» card, always first.
  final bool redFlag;

  /// Normalized keyword stems of all languages (see [normalizeText]).
  final List<String> keywords;
  final Map<String, dynamic> title;
  final Map<String, List<String>> answer;
  final List<AssistantAction> actions;

  List<String> answerFor(String lang) =>
      answer[lang] ?? answer['uz'] ?? const [];

  factory AssistantRule.fromMap(Map<String, dynamic> m) => AssistantRule(
    id: m['id'] as String,
    redFlag: m['red_flag'] as bool? ?? false,
    keywords: [
      for (final list in (m['keywords'] as Map).values)
        for (final k in list as List) normalizeText(k as String),
    ],
    title: Map<String, dynamic>.from(m['title'] as Map),
    answer: {
      for (final e in (m['answer'] as Map).entries)
        e.key as String: List<String>.from(e.value as List),
    },
    actions: [
      for (final a in m['actions'] as List? ?? const [])
        AssistantAction.fromMap(a as Map<String, dynamic>),
    ],
  );
}

/// Lowercase, without apostrophes of any kind (people often type «ogriyapti»
/// for «og‘riyapti»), ё → е, spaces collapsed.
String normalizeText(String s) => s
    .toLowerCase()
    .replaceAll(RegExp("[‘’ʻʼ`´']"), '')
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// How many of [rule]'s keywords occur in [normalized] at a word start
/// (so «сон» matches «сонливость» but not «персонал»).
int keywordHits(String normalized, AssistantRule rule) {
  var hits = 0;
  for (final k in rule.keywords) {
    final re = RegExp('(^|[^\\p{L}])${RegExp.escape(k)}', unicode: true);
    if (re.hasMatch(normalized)) hits++;
  }
  return hits;
}

/// Matching rules by hits, at most [max]; if any red flag matches — only
/// red flags.
List<AssistantRule> matchRules(
  String text,
  List<AssistantRule> rules, {
  int max = 2,
}) {
  final normalized = normalizeText(text);
  final scored = [
    for (final r in rules)
      if (keywordHits(normalized, r) case final hits when hits > 0)
        (rule: r, hits: hits),
  ];
  // An emergency answers alone: self-care tips next to it would dilute
  // «call 103».
  final urgent = [
    for (final s in scored)
      if (s.rule.redFlag) s,
  ];
  final shown = (urgent.isNotEmpty ? urgent : scored)
    ..sort((a, b) => b.hits.compareTo(a.hits));
  return [for (final s in shown.take(max)) s.rule];
}

const assistantRulesAsset = 'assets/core/assistant_rules.json';

/// Rules ship with the app (offline in both modes).
final assistantRulesProvider = FutureProvider<List<AssistantRule>>((ref) async {
  // cache: false — a cached asset future hangs the next widget test.
  final raw = await rootBundle.loadString(assistantRulesAsset, cache: false);
  return [
    for (final m in jsonDecode(raw) as List)
      AssistantRule.fromMap(m as Map<String, dynamic>),
  ];
});
