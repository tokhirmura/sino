import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/core/backend/backend.dart';
import 'package:sino/core/contracts/home_card.dart';
import 'package:sino/core/data/user.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/home/application/goal_order.dart';
import 'package:sino/features/home/application/sino_index.dart';
import 'package:sino/features/home/data/sino_data.dart';
import 'package:sino/features/home/presentation/home_screen.dart';

HomeCardSpec _card(String id, int order) => HomeCardSpec(
  id: id,
  order: order,
  builder: (_) => Text('card $id', key: ValueKey('card-$id')),
);

/// Same ids and orders as the real features.
final _cards = [
  _card('sos', 10),
  _card('weather', 20),
  _card('reminders', 30),
  _card('pharmacy', 40),
  _card('nutrition', 50),
  _card('workouts', 60),
  _card('vitals', 70),
  _card('breathing', 75),
  _card('doctors', 80),
  _card('assistant', 90),
];

List<String> _ids(List<HomeCardSpec> c) => [for (final x in c) x.id];

class _Repo implements SinoDataRepository {
  @override
  Future<SinoRaw> load({required DateTime from, required DateTime to}) =>
      FakeSinoDataRepository(clock: () => DateTime(2026, 11, 21, 20))
          .load(from: from, to: to);

  @override
  Future<bool> hasReservation() async => false;
}

void main() {
  group('orderCardsForGoal', () {
    test('no goal → order unchanged', () {
      expect(orderCardsForGoal(_cards, null), same(_cards));
    });

    test('SOS stays first, goal cards next, the rest keep their order', () {
      expect(_ids(orderCardsForGoal(_cards, HealthGoal.pressureSugar)), [
        'sos',
        'vitals',
        'reminders',
        'nutrition',
        'doctors',
        'weather',
        'pharmacy',
        'workouts',
        'breathing',
        'assistant',
      ]);
      expect(_ids(orderCardsForGoal(_cards, HealthGoal.loseWeight)).take(4), [
        'sos',
        'nutrition',
        'workouts',
        'vitals',
      ]);
      expect(_ids(orderCardsForGoal(_cards, HealthGoal.energy)).take(5), [
        'sos',
        'workouts',
        'breathing',
        'nutrition',
        'weather',
      ]);
      expect(_ids(orderCardsForGoal(_cards, HealthGoal.family)).take(4), [
        'sos',
        'reminders',
        'doctors',
        'pharmacy',
      ]);
    });

    test('every goal keeps all cards once; missing ids are ignored', () {
      for (final g in HealthGoal.values) {
        final out = orderCardsForGoal(_cards, g);
        expect(out.toSet(), _cards.toSet(), reason: g.code);
        expect(out, hasLength(_cards.length), reason: g.code);
      }
      final few = [_card('assistant', 90), _card('vitals', 70)];
      expect(_ids(orderCardsForGoal(few, HealthGoal.pressureSugar)), [
        'vitals',
        'assistant',
      ]);
    });
  });

  group('HealthGoal in the profile', () {
    test('codes match the migration; texts in 3 languages', () {
      expect(
        [for (final g in HealthGoal.values) g.code],
        ['lose_weight', 'energy', 'pressure_sugar', 'family'],
      );
      for (final g in HealthGoal.values) {
        expect(HealthGoal.byCode(g.code), g);
        for (final l in AppLang.values) {
          expect(g.title(l), isNotEmpty);
          expect(g.hint(l), isNotEmpty);
        }
      }
      expect(HealthGoal.byCode('nope'), isNull);
      expect(HealthGoal.byCode(null), isNull);
    });

    test('toMap writes goal only when chosen; fromMap reads it', () {
      const p = UserProfile(id: 'u', fullName: 'Aziz');
      expect(p.toMap().containsKey('goal'), isFalse);
      final withGoal = p.copyWith(goal: HealthGoal.energy);
      expect(withGoal.toMap()['goal'], 'energy');
      expect(UserProfile.fromMap(withGoal.toMap()).goal, HealthGoal.energy);
      expect(UserProfile.fromMap({'id': 'u', 'goal': 'bad'}).goal, isNull);
      // copyWith without goal keeps it.
      expect(withGoal.copyWith(fullName: 'B').goal, HealthGoal.energy);
    });
  });

  for (final lang in AppLang.values) {
    testWidgets('home with a goal (${lang.name}, 360 px): pill, cards lifted', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        PrefKeys.fakeSignedIn: true,
        PrefKeys.fakeProfile: jsonEncode(
          UserProfile.fake.copyWith(goal: HealthGoal.pressureSugar).toMap(),
        ),
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            useFakeProvider.overrideWithValue(true),
            sinoClockProvider.overrideWithValue(
              () => DateTime(2026, 11, 21, 20),
            ),
            sinoDataRepositoryProvider.overrideWithValue(_Repo()),
            homeCardsProvider.overrideWithValue(_cards),
            appLangProvider.overrideWith(() => _FixedLang(lang)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: lang.locale,
            supportedLocales: AppLang.locales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home-goal')), findsOneWidget);
      expect(
        find.text('🩺 ${HealthGoal.pressureSugar.title(lang)}'),
        findsOneWidget,
      );
      double y(String id) =>
          tester.getTopLeft(find.byKey(ValueKey('card-$id'))).dy;
      expect(y('sos'), lessThan(y('vitals')));
      expect(y('vitals'), lessThan(y('reminders')));
      expect(y('doctors'), lessThan(y('weather')));
      expect(tester.takeException(), isNull);
    });
  }
}

class _FixedLang extends AppLangNotifier {
  _FixedLang(this.lang);
  final AppLang lang;

  @override
  AppLang build() => lang;
}
