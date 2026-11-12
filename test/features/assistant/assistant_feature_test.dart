import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/app/app.dart';
import 'package:sino/app/feature_registry.dart';
import 'package:sino/app/router.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/assistant/application/chat_controller.dart';
import 'package:sino/features/assistant/assistant_feature.dart';
import 'package:sino/features/assistant/data/ai_assistant_repository.dart';
import 'package:sino/features/assistant/data/assistant_rules.dart';
import 'package:sino/features/assistant/presentation/assistant_screen.dart';

import '../../helpers/test_app.dart';

Future<List<AssistantRule>> _rules() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final raw = await rootBundle.loadString(assistantRulesAsset, cache: false);
  return [
    for (final m in jsonDecode(raw) as List)
      AssistantRule.fromMap(m as Map<String, dynamic>),
  ];
}

List<String> _ids(String text, List<AssistantRule> rules) => [
  for (final r in matchRules(text, rules)) r.id,
];

Future<List<Uri>> _pump(
  WidgetTester tester, {
  AppLang lang = AppLang.uz,
  AiAssistantRepository? ai,
}) async {
  tester.view.physicalSize = const Size(412, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <Uri>[];
  final prefs = await fakePrefs(signedIn: true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appOverrides(prefs: prefs, useFake: true),
        if (ai != null) aiAssistantRepositoryProvider.overrideWithValue(ai),
        assistantLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: lang.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const AssistantScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byTooltip('Yuborish'));
  await tester.pump(ChatNotifier.typingDelay);
  await tester.pumpAndSettle();
}

/// Records questions; replies with [reply] or throws [error].
class _StubAi implements AiAssistantRepository {
  _StubAi({this.reply, this.error});

  final AiReply? reply;
  final Object? error;
  final asked = <({String message, String lang, List<ChatTurn> history})>[];

  @override
  Future<AiReply?> ask(
    String message, {
    required String lang,
    List<ChatTurn> history = const [],
  }) async {
    asked.add((message: message, lang: lang, history: history));
    if (error != null) throw error!;
    return reply;
  }
}

const _aiHeadache = AiReply(
  text: 'Suv iching va dam oling.',
  redFlag: false,
  actions: [
    AssistantAction(type: ActionType.pharmacy, query: 'paracetamol'),
    AssistantAction(type: ActionType.open, route: AppRoutes.doctors),
  ],
);

void main() {
  test('assistant exposes its root route', () {
    final paths = [
      for (final r in assistantRoutes.whereType<GoRoute>()) r.path,
    ];
    expect(paths, contains(AppRoutes.assistant));
  });

  group('rules', () {
    late List<AssistantRule> rules;
    setUpAll(() async => rules = await _rules());

    test('7 topics + red flags, answers in uz/ru/en, valid routes', () {
      final ids = {for (final r in rules) r.id};
      expect(
        ids,
        containsAll([
          'headache',
          'fever',
          'cold',
          'stomach',
          'pressure',
          'sleep',
          'stress',
          'chest_pain',
          'breathing',
          'unconscious',
        ]),
      );
      final known = {for (final r in allRoutes.whereType<GoRoute>()) r.path};
      for (final r in rules) {
        final n = r.answerFor('uz').length;
        expect(n, greaterThan(0), reason: r.id);
        expect(r.answerFor('ru'), hasLength(n), reason: r.id);
        expect(r.answerFor('en'), hasLength(n), reason: r.id);
        expect(r.title.keys, containsAll(['uz', 'ru', 'en']), reason: r.id);
        if (r.redFlag) {
          expect(
            r.actions.any(
              (a) => a.type == ActionType.call && a.number == '103',
            ),
            isTrue,
            reason: r.id,
          );
        }
        for (final a in r.actions.where((a) => a.type == ActionType.open)) {
          expect(known, contains(a.route), reason: '${r.id}: ${a.route}');
        }
      }
    });

    test('quick questions match their topic in every language', () {
      const cases = {
        'headache': ['Boshim og‘riyapti', 'Болит голова', 'I have a headache'],
        'fever': ['Isitmam bor', 'Высокая температура', 'I have a fever'],
        'cold': ['Yo‘tal va tumov', 'Кашель и насморк', 'Cough and runny nose'],
        'stomach': ['Qornim og‘riyapti', 'Болит живот', 'Stomach ache'],
        'pressure': [
          'Bosimim oshdi',
          'Поднялось давление',
          'High blood pressure',
        ],
        'sleep': ['Uxlay olmayapman', 'Не могу уснуть', 'Can’t fall asleep'],
        'stress': [
          'Stress va xavotir',
          'Стресс и тревога',
          'Stress and anxiety',
        ],
      };
      for (final MapEntry(key: id, value: texts) in cases.entries) {
        for (final t in texts) {
          expect(_ids(t, rules).first, id, reason: t);
        }
      }
    });

    test('red flags answer alone', () {
      expect(_ids('Ko‘kragim og‘riyapti', rules), ['chest_pain']);
      expect(_ids('Болит голова и боль в груди', rules), ['chest_pain']);
      expect(_ids('Задыхаюсь', rules).first, 'breathing');
      expect(_ids('Dadam hushdan ketdi', rules).first, 'unconscious');
      expect(_ids('He fainted', rules).first, 'unconscious');
    });

    test('any Uzbek apostrophe works; word starts only; unknown → none', () {
      expect(_ids('boshim ogʻriyapti', rules).first, 'headache'); // U+02BB
      expect(_ids("boshim og'riyapti", rules).first, 'headache');
      expect(_ids('Персонал в клинике', rules), isEmpty); // not «сон»
      expect(_ids('qwerty', rules), isEmpty);
      expect(normalizeText('  O‘ZBEK   Ёж '), 'ozbek еж');
    });

    test('typed without apostrophes — red flags still caught', () {
      expect(
        _ids('Kokragim siqilyapti, yuragim ogriyapti', rules).first,
        'chest_pain',
      );
      expect(_ids('boshim ogriyapti', rules).first, 'headache');
      expect(_ids('nafas ololmayapman', rules).first, 'breathing');
      expect(_ids("I can't breathe", rules).first, 'breathing');
    });
  });

  testWidgets('disclaimer on top; quick question gets a topic reply', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Shifokor maslahatini almashtirmaydi'), findsOneWidget);
    await tester.tap(find.text('Boshim og‘riyapti'));
    await tester.pump(ChatNotifier.typingDelay);
    await tester.pumpAndSettle();
    expect(find.text('Bosh og‘rig‘i'), findsOneWidget);
    expect(find.text('Dorixonada: ibuprofen'), findsOneWidget);
    expect(find.text('Shifokorga yozilish'), findsOneWidget);
  });

  testWidgets('red flag → «103 ga qo‘ng‘iroq qiling» card, call opens dialer', (
    tester,
  ) async {
    final opened = await _pump(tester);
    await _ask(tester, 'Ko‘kragim og‘riyapti');
    expect(find.byKey(const ValueKey('red-flag-chest_pain')), findsOneWidget);
    expect(find.text('103 ga qo‘ng‘iroq qiling'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '103 ga qo‘ng‘iroq'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'tel:103');
  });

  testWidgets('not understood → suggestions; new chat clears', (tester) async {
    await _pump(tester);
    await _ask(tester, 'qwerty');
    expect(find.textContaining('Savolingizni tushunmadim'), findsOneWidget);
    await tester.tap(find.byTooltip('Yangi suhbat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Savolingizni tushunmadim'), findsNothing);
  });

  testWidgets('Russian UI answers in Russian', (tester) async {
    await _pump(tester, lang: AppLang.ru);
    expect(find.text('Не заменяет консультацию врача'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Болит живот');
    await tester.tap(find.byTooltip('Отправить'));
    await tester.pump(ChatNotifier.typingDelay);
    await tester.pumpAndSettle();
    expect(find.text('Живот и желудок'), findsOneWidget);
    expect(find.text('Питание'), findsOneWidget);
  });

  testWidgets('action button opens pharmacy search with the query', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpSinoApp(tester, signedIn: true);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SinoApp)),
    );
    final router = container.read(routerProvider);
    router.push(AppRoutes.assistant);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Boshim og‘riyapti'));
    await tester.pump(ChatNotifier.typingDelay);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dorixonada: ibuprofen'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      AppRoutes.pharmacySearch('ibuprofen'),
    );
  });

  group('LLM', () {
    test('reply parsing keeps only known actions', () {
      final r = AiReply.fromMap({
        'text': ' Salom ',
        'red_flag': true,
        'actions': [
          {'type': 'call', 'number': '103'},
          {'type': 'hack', 'route': '/x'},
        ],
      });
      expect(r.text, 'Salom');
      expect(r.redFlag, isTrue);
      expect(r.actions.single.type, ActionType.call);
    });

    testWidgets('answer from the LLM with buttons and an AI note', (
      tester,
    ) async {
      final ai = _StubAi(reply: _aiHeadache);
      await _pump(tester, ai: ai);
      await _ask(tester, 'Boshim og‘riyapti');
      expect(find.byKey(const ValueKey('ai-reply')), findsOneWidget);
      expect(find.text('Suv iching va dam oling.'), findsOneWidget);
      expect(find.text('Dorixonada: paracetamol'), findsOneWidget);
      expect(find.text('Sun’iy intellekt javobi'), findsOneWidget);
      expect(ai.asked.single.lang, 'uz');

      // Earlier turns go along as context.
      await _ask(tester, 'Yana nima qilay?');
      final history = ai.asked.last.history;
      expect(history.first, (fromUser: true, text: 'Boshim og‘riyapti'));
      expect(history.last.text, 'Suv iching va dam oling.');
    });

    testWidgets('red flag is answered locally — LLM not asked', (tester) async {
      final ai = _StubAi(reply: _aiHeadache);
      await _pump(tester, ai: ai);
      await _ask(tester, 'Ko‘kragim og‘riyapti');
      expect(ai.asked, isEmpty);
      expect(find.byKey(const ValueKey('red-flag-chest_pain')), findsOneWidget);
    });

    testWidgets('LLM error → offline rules answer', (tester) async {
      await _pump(tester, ai: _StubAi(error: Exception('offline')));
      await _ask(tester, 'Boshim og‘riyapti');
      expect(find.byKey(const ValueKey('ai-reply')), findsNothing);
      expect(find.text('Bosh og‘rig‘i'), findsOneWidget);
    });

    testWidgets('LLM red flag → red card with a 103 button', (tester) async {
      final opened = await _pump(
        tester,
        ai: _StubAi(
          reply: const AiReply(
            text: 'Bu shoshilinch holat bo‘lishi mumkin.',
            redFlag: true,
            actions: [AssistantAction(type: ActionType.call, number: '103')],
          ),
        ),
      );
      await _ask(tester, 'Bolamning harorati 40');
      expect(find.text('103 ga qo‘ng‘iroq qiling'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '103 ga qo‘ng‘iroq'));
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'tel:103');
    });
  });
}
