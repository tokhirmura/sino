import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/data/user.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/family/application/family_care.dart';
import 'package:sino/features/family/data/family_care_repository.dart';
import 'package:sino/features/family/family_feature.dart';
import 'package:sino/features/family/presentation/family_home_card.dart';
import 'package:sino/features/family/presentation/family_screen.dart';

/// Saturday 14:00.
final _now = DateTime(2026, 11, 21, 14);
final _today = DateTime(2026, 11, 21);

const _mom = FamilyMember(
  id: 'mom',
  name: 'Dilfuza',
  relation: 'ona',
  phone: '+998 90 123 45 67',
);
const _dad = FamilyMember(id: 'dad', name: 'Akbar', relation: 'ota');
const _kid = FamilyMember(id: 'kid', name: 'Malika', relation: 'qizi');

CareReminder _r(
  String id,
  String member,
  int hour, {
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  bool active = true,
  DateTime? since,
}) => CareReminder(
  id: id,
  memberId: member,
  name: 'Dori $id',
  minutes: hour * 60,
  days: days,
  active: active,
  since: since,
);

CareLog _log(String id, int hour) =>
    CareLog(id, _today.add(Duration(hours: hour, minutes: 5)));

class _FixedLang extends AppLangNotifier {
  _FixedLang(this.lang);
  final AppLang lang;

  @override
  AppLang build() => lang;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildFamilyCare', () {
    test('today\'s doses per member: weekday, paused, created later', () {
      final care = buildFamilyCare(
        [_mom, _dad],
        FamilyCareRaw(
          reminders: [
            _r('a', 'mom', 8),
            _r('b', 'mom', 13),
            _r('c', 'mom', 9, days: const [1]), // Monday only
            _r('d', 'mom', 10, active: false),
            _r('e', 'mom', 11, since: _today.add(const Duration(days: 1))),
            _r('f', 'dad', 8),
            _r('g', 'someone-else', 8),
          ],
          logs: [
            _log('a', 8),
            CareLog(
              'f',
              _today.subtract(const Duration(hours: 2)),
            ), // yesterday
          ],
          visits: [
            CareVisit(
              memberId: 'dad',
              startsAt: _today.add(const Duration(days: 5, hours: 15)),
              doctor: 'Tursunov',
            ),
          ],
          reservations: const [
            CareReservation(memberId: 'mom', medicine: 'X', status: 'ready'),
          ],
        ),
        _now,
      );
      final mom = care[0], dad = care[1];
      expect([for (final d in mom.doses) d.name], ['Dori a', 'Dori b']);
      expect(mom.taken, 1);
      expect(mom.total, 2);
      expect(mom.reservation!.ready, isTrue);
      expect(dad.taken, 0, reason: 'yesterday\'s mark doesn\'t count');
      expect(dad.visit!.doctor, 'Tursunov');
      expect(mom.visit, isNull);
    });

    test('missed only 30 min after the time', () {
      final at13 = DateTime(2026, 11, 21, 13);
      final dose = CareDose(name: 'x', at: at13, taken: false);
      expect(dose.missedAt(DateTime(2026, 11, 21, 13, 30)), isFalse);
      expect(dose.missedAt(DateTime(2026, 11, 21, 13, 31)), isTrue);
      final taken = CareDose(name: 'x', at: at13, taken: true);
      expect(taken.missedAt(_now), isFalse);
    });

    test('summary: 3 with medicines, 2 on track, mom missed', () {
      final care = buildFamilyCare(
        [
          _mom,
          _dad,
          _kid,
          const FamilyMember(id: 'x', name: 'X', relation: 'boshqa'),
        ],
        FamilyCareRaw(
          reminders: [
            _r('a', 'mom', 8),
            _r('b', 'mom', 12),
            _r('c', 'dad', 8),
            _r('d', 'kid', 20),
          ],
          logs: [_log('a', 8), _log('c', 8)],
        ),
        _now,
      );
      final s = summarizeFamily(care, _now);
      expect(s.members, 4);
      expect(s.withMedicines, 3);
      expect(s.onTrack, 2);
      expect([for (final c in s.missed) c.member.id], ['mom']);
    });
  });

  test('parseFamilyCareRows: embedded names, UTC → local', () {
    final raw = parseFamilyCareRows(
      reminders: [
        {
          'id': 'r1',
          'member_id': 'mom',
          'name': 'Lozartan',
          'dose': '50 mg',
          'time': '13:30:00',
          'days': [1, 3],
          'active': true,
          'created_at': '2026-11-20T05:00:00Z',
        },
      ],
      logs: [
        {'reminder_id': 'r1', 'taken_at': '2026-11-21T08:35:00Z'},
      ],
      visits: [
        {
          'member_id': 'dad',
          'starts_at': '2026-11-26T10:00:00Z',
          'online': true,
          'doctors': {'name': 'Tursunov', 'specialty': 'Kardiolog'},
        },
      ],
      reservations: [
        {
          'for_member_id': 'mom',
          'status': 'pending',
          'medicines': {'name': 'Lozartan 50 mg'},
          'pharmacies': {'name': 'Malham'},
        },
      ],
    );
    final r = raw.reminders.single;
    expect(r.minutes, 13 * 60 + 30);
    expect(r.days, [1, 3]);
    expect(r.since, isNotNull);
    expect(raw.logs.single.takenAt.isUtc, isFalse);
    expect(raw.visits.single.specialty, 'Kardiolog');
    expect(raw.visits.single.online, isTrue);
    expect(raw.reservations.single.pharmacy, 'Malham');
    expect(raw.reservations.single.ready, isFalse);
  });

  test('fake day: mom has one taken, one missed — at any hour', () async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/core/family_care.json', cache: false),
    ) as Map<String, dynamic>;
    for (final hour in [7, 11, 14, 19, 22]) {
      final now = DateTime(2026, 11, 21, hour);
      final care = buildFamilyCare(
        FamilyMember.fakes,
        buildFakeFamilyCare(json, now),
        now,
      );
      final mom = care.firstWhere((c) => c.member.relation == 'ona');
      expect(mom.total, 2, reason: '$hour:00');
      expect(mom.taken, 1, reason: '$hour:00');
      expect(mom.missedAt(now), hasLength(1), reason: '$hour:00');
      final s = summarizeFamily(care, now);
      expect([for (final c in s.missed) c.member.relation], ['ona']);
    }
  });

  test('FamilyMember.phone: map round trip and dialable', () {
    expect(UserProfile.fake.id, isNotEmpty);
    final m = FamilyMember.fromMap({..._mom.toMap(), 'id': 'mom'});
    expect(m.phone, '+998 90 123 45 67');
    expect(m.dialable, '+998901234567');
    expect(_dad.dialable, isNull);
    expect(
      const FamilyMember(
        id: 'x',
        name: 'x',
        relation: 'ona',
        phone: '12',
      ).dialable,
      isNull,
    );
  });

  test('family exports /family and the home card', () {
    expect(familyRoutes.whereType<GoRoute>().map((r) => r.path), [
      AppRoutes.family,
    ]);
    expect(familyHomeCards.single.id, 'family');
  });

  Future<List<String>> pumpFamily(
    WidgetTester tester, {
    AppLang lang = AppLang.uz,
    Widget screen = const FamilyScreen(),
    List<FamilyMember>? family,
  }) async {
    tester.view.physicalSize = const Size(412, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      PrefKeys.fakeSignedIn: true,
      if (family != null)
        PrefKeys.fakeFamily: jsonEncode([
          for (final m in family) {...m.toMap(), 'id': m.id},
        ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final dialed = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appOverrides(prefs: prefs, useFake: true),
          familyClockProvider.overrideWithValue(() => _now),
          dialerProvider.overrideWithValue((p) async {
            dialed.add(p);
            return true;
          }),
          appLangProvider.overrideWith(() => _FixedLang(lang)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: lang.locale,
          supportedLocales: AppLang.locales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return dialed;
  }

  testWidgets('/family: cards, mom missed → red alert, call', (tester) async {
    final dialed = await pumpFamily(tester);

    expect(find.text('Oila'), findsOneWidget);
    expect(find.text('3 kishidan 2 nafari dorini ichdi'), findsOneWidget);
    for (final id in ['fake-mother', 'fake-father', 'fake-daughter']) {
      expect(find.byKey(ValueKey('member-$id')), findsOneWidget, reason: id);
    }
    expect(find.byKey(const ValueKey('missed-fake-mother')), findsOneWidget);
    expect(find.text('Onam dorini ichmadi'), findsOneWidget);
    expect(find.byKey(const ValueKey('missed-fake-father')), findsNothing);
    expect(find.byKey(const ValueKey('taken-fake-mother')), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    // Dad's visit, mom's ready reservation.
    expect(find.textContaining('Tursunov Bahodir'), findsOneWidget);
    expect(find.textContaining('Malham dorixonasi'), findsOneWidget);
    expect(find.text('Tayyor'), findsOneWidget);
    expect(find.byKey(const ValueKey('family-future')), findsOneWidget);
    expect(find.text('Shifokor maslahatini almashtirmaydi'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('call-fake-mother')));
    await tester.pump();
    expect(dialed, ['+998901234567']);
  });

  testWidgets('missed without a phone → «add a phone»', (tester) async {
    await pumpFamily(
      tester,
      family: const [
        FamilyMember(id: 'fake-mother', name: 'Dilfuza', relation: 'ona'),
      ],
    );
    expect(find.text('Onam dorini ichmadi'), findsOneWidget);
    expect(find.byKey(const ValueKey('call-fake-mother')), findsNothing);
    expect(find.byKey(const ValueKey('add-phone-fake-mother')), findsOneWidget);
  });

  testWidgets('no family → empty state; «Kelajakda» still shown', (
    tester,
  ) async {
    await pumpFamily(tester, family: const []);
    expect(find.text('Oila a’zolarini qo‘shing'), findsOneWidget);
    expect(find.byKey(const ValueKey('family-future')), findsOneWidget);
  });

  testWidgets('ru / en texts', (tester) async {
    await pumpFamily(tester, lang: AppLang.ru);
    expect(find.text('Семья'), findsOneWidget);
    expect(find.text('Dilfuza: лекарство не принято'), findsOneWidget);
    expect(find.text('Позвонить'), findsOneWidget);
    expect(find.text('Лекарства вовремя: 2 из 3'), findsOneWidget);
  });

  testWidgets('home card: summary and who missed', (tester) async {
    await pumpFamily(tester, screen: const FamilyHomeCard());
    expect(find.text('3 kishidan 2 nafari dorini ichdi'), findsOneWidget);
    expect(find.text('⚠️ Onam dorini ichmadi'), findsOneWidget);
  });

  testWidgets('home card without family invites to add', (tester) async {
    await pumpFamily(tester, screen: const FamilyHomeCard(), family: const []);
    expect(
      find.text('Yaqinlaringizni qo‘shing — dorilarini kuzating'),
      findsOneWidget,
    );
  });
}
