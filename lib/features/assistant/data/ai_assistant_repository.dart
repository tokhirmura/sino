import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';
import 'assistant_rules.dart';

/// A reply from the LLM (Edge Function `assistant`).
class AiReply {
  const AiReply({
    required this.text,
    required this.redFlag,
    required this.actions,
  });

  final String text;
  final bool redFlag;
  final List<AssistantAction> actions;

  factory AiReply.fromMap(Map<String, dynamic> m) => AiReply(
    text: (m['text'] as String).trim(),
    redFlag: m['red_flag'] == true,
    actions: [
      for (final a in m['actions'] as List? ?? const [])
        if (_known(a)) AssistantAction.fromMap(Map<String, dynamic>.from(a)),
    ],
  );

  static bool _known(Object? a) =>
      a is Map && ActionType.values.any((t) => t.name == a['type']);
}

/// One earlier chat line sent as context.
typedef ChatTurn = ({bool fromUser, String text});

/// LLM answers. Rules (`assistant_rules.json`) stay the fallback.
abstract class AiAssistantRepository {
  /// `null` — LLM not available here (fake mode); throws on errors.
  Future<AiReply?> ask(
    String message, {
    required String lang,
    List<ChatTurn> history = const [],
  });
}

class SupabaseAiAssistantRepository implements AiAssistantRepository {
  SupabaseAiAssistantRepository(this._client);

  final SupabaseClient _client;

  static const timeout = Duration(seconds: 20);

  @override
  Future<AiReply?> ask(
    String message, {
    required String lang,
    List<ChatTurn> history = const [],
  }) async {
    final res = await _client.functions
        .invoke(
          'assistant',
          body: {
            'message': message,
            'lang': lang,
            'history': [
              for (final t in history)
                {'role': t.fromUser ? 'user' : 'assistant', 'text': t.text},
            ],
          },
        )
        .timeout(timeout);
    return AiReply.fromMap(Map<String, dynamic>.from(res.data as Map));
  }
}

/// Offline: no LLM — the chat answers with rules only.
class FakeAiAssistantRepository implements AiAssistantRepository {
  @override
  Future<AiReply?> ask(
    String message, {
    required String lang,
    List<ChatTurn> history = const [],
  }) async => null;
}

final aiAssistantRepositoryProvider = Provider<AiAssistantRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeAiAssistantRepository()
      : SupabaseAiAssistantRepository(ref.watch(supabaseClientProvider)),
);
