import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/ai_assistant_repository.dart';
import '../data/assistant_rules.dart';

/// A chat bubble. User: [text]. Assistant: [ai] (LLM) or [rules]
/// (empty rules and no [ai] = didn't understand → suggestions).
class ChatMessage {
  const ChatMessage.user(this.text)
    : fromUser = true,
      rules = const [],
      ai = null;
  const ChatMessage.assistant(this.rules)
    : fromUser = false,
      text = null,
      ai = null;
  const ChatMessage.ai(AiReply this.ai)
    : fromUser = false,
      text = null,
      rules = const [];

  final bool fromUser;
  final String? text;
  final List<AssistantRule> rules;
  final AiReply? ai;

  /// What the LLM sees of this line as context; null — skip it.
  String? get contextText => fromUser
      ? text
      : ai?.text ??
            (rules.isEmpty ? null : rules.first.answerFor('en').join(' '));
}

class ChatState {
  const ChatState({this.messages = const [], this.typing = false});

  final List<ChatMessage> messages;

  /// Assistant «is typing» — a short pause feels more natural.
  final bool typing;
}

/// Chat: red flags answered locally by rules (instant, offline); the rest
/// by the LLM, falling back to rules on any error or in fake mode.
/// Keeps the conversation while the app runs.
class ChatNotifier extends Notifier<ChatState> {
  static const typingDelay = Duration(milliseconds: 500);

  @override
  ChatState build() => const ChatState();

  Future<void> send(String text, {String lang = 'uz'}) async {
    final q = text.trim();
    if (q.isEmpty || state.typing) return;
    final history = [
      for (final m in state.messages)
        if (m.contextText case final t?) (fromUser: m.fromUser, text: t),
    ];
    state = ChatState(
      messages: [...state.messages, ChatMessage.user(q)],
      typing: true,
    );
    final started = DateTime.now();

    List<AssistantRule> matched;
    try {
      final rules = await ref.read(assistantRulesProvider.future);
      matched = matchRules(q, rules);
    } catch (_) {
      matched = const [];
    }

    ChatMessage reply = ChatMessage.assistant(matched);
    final urgent = matched.any((r) => r.redFlag);
    if (!urgent) {
      try {
        final ai = await ref
            .read(aiAssistantRepositoryProvider)
            .ask(q, lang: lang, history: history);
        if (ai != null) reply = ChatMessage.ai(ai);
      } catch (_) {
        // Offline / function not deployed / LLM error → rules answer.
      }
    }

    final left = typingDelay - DateTime.now().difference(started);
    if (left > Duration.zero) await Future<void>.delayed(left);
    state = ChatState(messages: [...state.messages, reply]);
  }

  void clear() => state = const ChatState();
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);

/// Opens the dialer (never calls by itself). Overridden in tests.
final assistantLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
