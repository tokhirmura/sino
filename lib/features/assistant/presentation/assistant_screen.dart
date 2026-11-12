import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../application/chat_controller.dart';
import '../data/ai_assistant_repository.dart';
import '../data/assistant_rules.dart';

/// Quick questions; each text contains its topic's keywords.
List<String> suggestions(BuildContext c) => [
  c.tr(uz: 'Boshim og‘riyapti', ru: 'Болит голова', en: 'I have a headache'),
  c.tr(uz: 'Isitmam bor', ru: 'Высокая температура', en: 'I have a fever'),
  c.tr(
    uz: 'Yo‘tal va tumov',
    ru: 'Кашель и насморк',
    en: 'Cough and runny nose',
  ),
  c.tr(uz: 'Qornim og‘riyapti', ru: 'Болит живот', en: 'Stomach ache'),
  c.tr(
    uz: 'Bosimim oshdi',
    ru: 'Поднялось давление',
    en: 'High blood pressure',
  ),
  c.tr(uz: 'Uxlay olmayapman', ru: 'Не могу уснуть', en: 'Can’t fall asleep'),
  c.tr(
    uz: 'Stress va xavotir',
    ru: 'Стресс и тревога',
    en: 'Stress and anxiety',
  ),
];

/// Bottom tabs are switched with `go`, other screens are pushed.
const _tabs = {
  AppRoutes.home,
  AppRoutes.pharmacy,
  AppRoutes.nutrition,
  AppRoutes.workouts,
  AppRoutes.profile,
};

(IconData, String) _actionLook(BuildContext c, AssistantAction a) =>
    switch (a.type) {
      ActionType.call => (
        Icons.call,
        c.tr(
          uz: '${a.number} ga qo‘ng‘iroq',
          ru: 'Позвонить ${a.number}',
          en: 'Call ${a.number}',
        ),
      ),
      ActionType.pharmacy => (
        Icons.local_pharmacy_outlined,
        c.tr(
          uz: 'Dorixonada: ${a.query}',
          ru: 'В аптеке: ${a.query}',
          en: 'Pharmacy: ${a.query}',
        ),
      ),
      ActionType.open => switch (a.route) {
        AppRoutes.doctors => (
          Icons.medical_services_outlined,
          c.tr(
            uz: 'Shifokorga yozilish',
            ru: 'Записаться к врачу',
            en: 'Book a doctor',
          ),
        ),
        AppRoutes.vitals => (
          Icons.monitor_heart_outlined,
          c.tr(
            uz: 'Ko‘rsatkichlarni yozish',
            ru: 'Записать показатели',
            en: 'Log vitals',
          ),
        ),
        AppRoutes.reminders => (
          Icons.alarm,
          c.tr(
            uz: 'Dori eslatmasi',
            ru: 'Напоминание о лекарстве',
            en: 'Medication reminder',
          ),
        ),
        AppRoutes.nutrition => (
          Icons.restaurant_outlined,
          c.tr(uz: 'Ovqatlanish', ru: 'Питание', en: 'Nutrition'),
        ),
        AppRoutes.workouts => (
          Icons.directions_walk,
          c.tr(uz: 'Mashg‘ulotlar', ru: 'Тренировки', en: 'Workouts'),
        ),
        AppRoutes.weather => (
          Icons.cloud_outlined,
          c.tr(uz: 'Havo sifati', ru: 'Качество воздуха', en: 'Air quality'),
        ),
        AppRoutes.sos => (
          Icons.sos,
          c.tr(
            uz: 'SOS va birinchi yordam',
            ru: 'SOS и первая помощь',
            en: 'SOS and first aid',
          ),
        ),
        _ => (Icons.open_in_new, a.route ?? ''),
      },
    };

/// Rule-based health assistant chat.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final q = text ?? _input.text;
    if (q.trim().isEmpty) return;
    _input.clear();
    ref.read(chatProvider.notifier).send(q, lang: context.lang.name);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _run(AssistantAction a) async {
    switch (a.type) {
      case ActionType.pharmacy:
        context.go(AppRoutes.pharmacySearch(a.query ?? ''));
      case ActionType.open:
        final route = a.route!;
        _tabs.contains(route) ? context.go(route) : context.push(route);
      case ActionType.call:
        var ok = false;
        try {
          ok = await ref.read(assistantLauncherProvider)(
            Uri(scheme: 'tel', path: a.number),
          );
        } catch (_) {}
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  uz: '${a.number} raqamini qo‘lda tering.',
                  ru: 'Наберите ${a.number} вручную.',
                  en: 'Dial ${a.number} manually.',
                ),
              ),
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    ref.listen(chatProvider, (_, _) => _scrollToEnd());
    return AppScaffold(
      title: context.tr(uz: 'Yordamchi', ru: 'Ассистент', en: 'Assistant'),
      padding: EdgeInsets.zero,
      actions: [
        if (chat.messages.isNotEmpty)
          IconButton(
            tooltip: context.tr(
              uz: 'Yangi suhbat',
              ru: 'Новый диалог',
              en: 'New chat',
            ),
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(chatProvider.notifier).clear(),
          ),
      ],
      body: Column(
        children: [
          const _Disclaimer(),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                _Bubble(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          uz:
                              'Salom! Men Sino yordamchisiman. Nimadan '
                              'bezovtasiz? O‘zbek, rus yoki ingliz tilida '
                              'yozing.',
                          ru:
                              'Здравствуйте! Я ассистент Sino. Что вас '
                              'беспокоит? Пишите на узбекском, русском или '
                              'английском.',
                          en:
                              'Hi! I’m the Sino assistant. What’s bothering '
                              'you? Write in Uzbek, Russian or English.',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Suggestions(onTap: _send),
                    ],
                  ),
                ),
                for (final m in chat.messages)
                  if (m.fromUser)
                    _Bubble(fromUser: true, child: Text(m.text!))
                  else if (m.ai != null)
                    _AiReplyCard(reply: m.ai!, onAction: _run)
                  else if (m.rules.isEmpty)
                    _NotUnderstood(onSuggestion: _send, onAction: _run)
                  else
                    for (final r in m.rules)
                      r.redFlag
                          ? _RedFlagCard(rule: r, onAction: _run)
                          : _RuleReply(rule: r, onAction: _run),
                if (chat.typing)
                  const _Bubble(
                    child: SizedBox(
                      width: 36,
                      child: LinearProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: context.tr(
                          uz: 'Belgilaringizni yozing…',
                          ru: 'Опишите симптомы…',
                          en: 'Describe your symptoms…',
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: context.tr(
                      uz: 'Yuborish',
                      ru: 'Отправить',
                      en: 'Send',
                    ),
                    onPressed: chat.typing ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.amber.withValues(alpha: 0.16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr(
                uz: 'Shifokor maslahatini almashtirmaydi',
                ru: 'Не заменяет консультацию врача',
                en: 'Does not replace a doctor’s advice',
              ),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.child, this.fromUser = false, this.color});

  final Widget child;
  final bool fromUser;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? (fromUser ? AppColors.primary : scheme.surface);
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (fromUser ? 0.8 : 0.92),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(fromUser ? 18 : 4),
              bottomRight: Radius.circular(fromUser ? 4 : 18),
            ),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: fromUser ? Colors.white : null),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final s in suggestions(context))
        ActionChip(label: Text(s), onPressed: () => onTap(s)),
    ],
  );
}

class _Actions extends StatelessWidget {
  const _Actions({required this.actions, required this.onAction});

  final List<AssistantAction> actions;
  final ValueChanged<AssistantAction> onAction;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final a in actions)
        if (_actionLook(context, a) case (final icon, final label))
          ActionChip(
            avatar: Icon(icon, size: 18),
            label: Text(label),
            onPressed: () => onAction(a),
          ),
    ],
  );
}

class _Lines extends StatelessWidget {
  const _Lines(this.lines);

  final List<String> lines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final l in lines)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(l)),
            ],
          ),
        ),
    ],
  );
}

class _RuleReply extends StatelessWidget {
  const _RuleReply({required this.rule, required this.onAction});

  final AssistantRule rule;
  final ValueChanged<AssistantAction> onAction;

  @override
  Widget build(BuildContext context) {
    return _Bubble(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.trMap(rule.title),
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _Lines(rule.answerFor(context.lang.name)),
          const SizedBox(height: 6),
          _Actions(actions: rule.actions, onAction: onAction),
        ],
      ),
    );
  }
}

class _RedFlagCard extends StatelessWidget {
  const _RedFlagCard({required this.rule, required this.onAction});

  final AssistantRule rule;
  final ValueChanged<AssistantAction> onAction;

  @override
  Widget build(BuildContext context) {
    final call = rule.actions.where((a) => a.type == ActionType.call);
    final rest = rule.actions.where((a) => a.type != ActionType.call);
    return _Bubble(
      color: AppColors.danger.withValues(alpha: 0.14),
      child: Column(
        key: ValueKey('red-flag-${rule.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚨', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(
                    uz: '103 ga qo‘ng‘iroq qiling',
                    ru: 'Позвоните 103',
                    en: 'Call 103',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.trMap(rule.title),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          _Lines(rule.answerFor(context.lang.name)),
          const SizedBox(height: 8),
          for (final a in call)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () => onAction(a),
              icon: const Icon(Icons.call),
              label: Text(_actionLook(context, a).$2),
            ),
          const SizedBox(height: 6),
          _Actions(actions: rest.toList(), onAction: onAction),
        ],
      ),
    );
  }
}

class _NotUnderstood extends StatelessWidget {
  const _NotUnderstood({required this.onSuggestion, required this.onAction});

  final ValueChanged<String> onSuggestion;
  final ValueChanged<AssistantAction> onAction;

  @override
  Widget build(BuildContext context) {
    return _Bubble(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(
              uz:
                  'Savolingizni tushunmadim. Belgilaringizni oddiy so‘zlar '
                  'bilan yozing yoki mavzuni tanlang. Yaxshi his '
                  'qilmasangiz — shifokorga murojaat qiling.',
              ru:
                  'Я не понял вопрос. Опишите симптомы простыми словами или '
                  'выберите тему. Если вам плохо — обратитесь к врачу.',
              en:
                  'I didn’t understand. Describe your symptoms in simple '
                  'words or pick a topic. If you feel unwell, see a doctor.',
            ),
          ),
          const SizedBox(height: 10),
          _Suggestions(onTap: onSuggestion),
          const SizedBox(height: 6),
          _Actions(
            actions: const [
              AssistantAction(type: ActionType.open, route: AppRoutes.doctors),
            ],
            onAction: onAction,
          ),
        ],
      ),
    );
  }
}

/// LLM answer: text, action buttons, a small «AI» note. Red flag → red
/// card with a big 103 button, like the rule-based one.
class _AiReplyCard extends StatelessWidget {
  const _AiReplyCard({required this.reply, required this.onAction});

  final AiReply reply;
  final ValueChanged<AssistantAction> onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final red = reply.redFlag;
    final call = reply.actions.where((a) => a.type == ActionType.call);
    final rest = reply.actions.where((a) => a.type != ActionType.call);
    return _Bubble(
      color: red ? AppColors.danger.withValues(alpha: 0.14) : null,
      child: Column(
        key: const ValueKey('ai-reply'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (red) ...[
            Row(
              children: [
                const Text('🚨', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr(
                      uz: '103 ga qo‘ng‘iroq qiling',
                      ru: 'Позвоните 103',
                      en: 'Call 103',
                    ),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Text(reply.text),
          const SizedBox(height: 8),
          if (red)
            for (final a in call)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: () => onAction(a),
                  icon: const Icon(Icons.call),
                  label: Text(_actionLook(context, a).$2),
                ),
              ),
          _Actions(
            actions: red ? rest.toList() : reply.actions,
            onAction: onAction,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: text.bodySmall?.color),
              const SizedBox(width: 4),
              Text(
                context.tr(
                  uz: 'Sun’iy intellekt javobi',
                  ru: 'Ответ ИИ',
                  en: 'AI answer',
                ),
                style: text.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
