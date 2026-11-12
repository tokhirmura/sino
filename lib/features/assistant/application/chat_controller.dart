import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/assistant_rules.dart';

/// A chat bubble. User: [text]. Assistant: [rules] (empty = didn't
/// understand → suggestions).
class ChatMessage {
  const ChatMessage.user(this.text) : fromUser = true, rules = const [];
  const ChatMessage.assistant(this.rules) : fromUser = false, text = null;

  final bool fromUser;
  final String? text;
  final List<AssistantRule> rules;
}

class ChatState {
  const ChatState({this.messages = const [], this.typing = false});

  final List<ChatMessage> messages;

  /// Assistant «is typing» — a short pause feels more natural.
  final bool typing;
}

/// Rule-based chat. Keeps the conversation while the app runs.
class ChatNotifier extends Notifier<ChatState> {
  static const typingDelay = Duration(milliseconds: 500);

  @override
  ChatState build() => const ChatState();

  Future<void> send(String text) async {
    final q = text.trim();
    if (q.isEmpty || state.typing) return;
    state = ChatState(
      messages: [...state.messages, ChatMessage.user(q)],
      typing: true,
    );
    List<AssistantRule> matched;
    try {
      final rules = await ref.read(assistantRulesProvider.future);
      matched = matchRules(q, rules);
    } catch (_) {
      matched = const [];
    }
    await Future<void>.delayed(typingDelay);
    state = ChatState(
      messages: [...state.messages, ChatMessage.assistant(matched)],
    );
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
