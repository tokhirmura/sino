import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/data/user.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/theme/theme_mode.dart';
import 'package:sino/features/profile/application/doctor_qr.dart';
import 'package:sino/features/profile/data/medical_repository.dart';
import 'package:sino/features/profile/presentation/doctor_qr_screen.dart';
import 'package:sino/features/profile/presentation/lab_results_screen.dart';
import 'package:sino/features/profile/presentation/medical_records_screen.dart';
import 'package:sino/features/profile/presentation/profile_screen.dart';
import 'package:sino/features/profile/profile_feature.dart';

import '../../helpers/test_app.dart';

/// Tall phone so lazy lists build every item.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Full app (fake, signed in) on the profile tab; returns the container.
Future<ProviderContainer> _openProfileTab(WidgetTester tester) async {
  _tallView(tester);
  await pumpSinoApp(tester, signedIn: true);
  await tester.tap(find.byIcon(Icons.person_outline));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SinoApp)));
}

LabResult _lab(double v, {double? lo, double? hi}) => LabResult(
  id: 'l',
  name: 'X',
  value: v,
  refLow: lo,
  refHigh: hi,
  takenAt: DateTime(2026),
);

String _tr({required String uz, String? ru, String? en}) => uz;

void main() {
  test('profile exposes its root route and sub-screens', () {
    final root = profileRoutes.whereType<GoRoute>().single;
    expect(root.path, AppRoutes.profile);
    expect(
      [for (final r in root.routes.whereType<GoRoute>()) r.path],
      [
        'edit',
        'records',
        'labs',
        'qr',
        'achievements',
        'family/new',
        'family/:id',
      ],
    );
  });

  group('lab results', () {
    test('status vs reference range', () {
      expect(_lab(5, lo: 4, hi: 9).status, LabStatus.normal);
      expect(_lab(3, lo: 4, hi: 9).status, LabStatus.low);
      expect(_lab(10, lo: 4, hi: 9).status, LabStatus.high);
      expect(_lab(10).status, LabStatus.normal);
    });

    test('scale always shows the value and the normal zone', () {
      for (final l in [
        _lab(5.6, lo: 0, hi: 5.2),
        _lab(18, lo: 30, hi: 100),
        _lab(142, lo: 130, hi: 170),
        _lab(7),
      ]) {
        final (min, max) = LabScale.bounds(l);
        expect(min, lessThanOrEqualTo(l.value));
        expect(max, greaterThan(l.value));
        expect(min, greaterThanOrEqualTo(0));
        if (l.refHigh != null) expect(max, greaterThan(l.refHigh!));
      }
    });
  });

  group('doctor QR text', () {
    final profile = UserProfile(
      id: 'u',
      fullName: 'Aziz Karimov',
      birthYear: 1997,
      heightCm: 178,
      weightKg: 76,
      bloodType: 'A(II) Rh+',
      allergies: const ['Penitsillin'],
    );
    final records = [
      MedicalRecord(
        id: '1',
        date: DateTime(2026, 10, 1),
        kind: 'diagnosis',
        title: 'Gastrit',
        source: RecordSource.xususiy,
      ),
      MedicalRecord(
        id: '2',
        memberId: 'mother',
        date: DateTime(2026, 10, 2),
        kind: 'diagnosis',
        title: 'Gipertoniya',
        source: RecordSource.davlat,
      ),
    ];

    test('contains only the chosen fields and only own records', () {
      final text = buildDoctorQrText(
        profile: profile,
        records: records,
        labs: [_lab(5.6, lo: 0, hi: 5.2)],
        fields: {QrField.bloodType, QrField.diagnoses},
        tr: _tr,
        now: DateTime(2026, 11, 12),
      );
      expect(text, contains('Qon guruhi: A(II) Rh+'));
      expect(text, contains('Gastrit (01.10.2026)'));
      expect(text, isNot(contains('Gipertoniya')));
      expect(text, isNot(contains('Aziz')));
      expect(text, isNot(contains('Penitsillin')));
      expect(text, isNot(contains('X: 5.6')));
    });

    test('basics, allergies and labs (out of range marked)', () {
      final text = buildDoctorQrText(
        profile: profile,
        records: records,
        labs: [_lab(5.6, lo: 0, hi: 5.2)],
        fields: {QrField.basics, QrField.allergies, QrField.labs},
        tr: _tr,
        now: DateTime(2026, 11, 12),
      );
      expect(text, contains('Ism: Aziz Karimov'));
      expect(text, contains('Tug‘ilgan yil: 1997 (29)'));
      expect(text, contains('178 sm / 76 kg'));
      expect(text, contains('Allergiya: Penitsillin'));
      expect(text, contains('X: 5.6 (!)'));
    });
  });

  testWidgets('profile: user card, medical shortcuts, family, settings', (
    tester,
  ) async {
    _tallView(tester);
    await pumpScreen(tester, const ProfileScreen());
    expect(find.text('Aziz'), findsOneWidget);
    expect(find.text('29 yosh · 178 sm · 76 kg'), findsOneWidget);
    expect(find.text('A(II) Rh+'), findsOneWidget);
    expect(find.text('Penitsillin'), findsOneWidget);
    expect(find.text('8 ta yozuv · davlat va xususiy'), findsOneWidget);
    expect(find.text('7 ta · 2 tasi me’yordan tashqarida'), findsOneWidget);
    expect(find.text('Malika, 5'), findsOneWidget);
    expect(find.text('Sozlamalar'), findsOneWidget);
  });

  testWidgets('medical record: feed with source labels, filter by person', (
    tester,
  ) async {
    _tallView(tester);
    await pumpScreen(tester, const MedicalRecordsScreen());
    expect(find.text('Terapevt ko‘rigi'), findsOneWidget);
    expect(find.text('Arterial gipertoniya, 1-daraja'), findsOneWidget);
    expect(find.text('Davlat'), findsWidgets);
    expect(find.text('Xususiy'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Dilfuza'));
    await tester.pumpAndSettle();
    expect(find.text('Arterial gipertoniya, 1-daraja'), findsOneWidget);
    expect(find.text('Terapevt ko‘rigi'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Men'));
    await tester.pumpAndSettle();
    expect(find.text('Terapevt ko‘rigi'), findsOneWidget);
    expect(find.text('Arterial gipertoniya, 1-daraja'), findsNothing);
  });

  testWidgets('lab results: summary and scale per result', (tester) async {
    _tallView(tester);
    await pumpScreen(tester, const LabResultsScreen());
    expect(find.text('7 tadan 2 tasi me’yordan tashqarida'), findsOneWidget);
    expect(find.text('Umumiy xolesterin'), findsOneWidget);
    expect(find.byType(LabScale), findsNWidgets(7));
    expect(find.text('Yuqori'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.textContaining('Shifokor maslahatini'), findsOneWidget);
  });

  testWidgets('doctor QR: shows a code, switches change the content', (
    tester,
  ) async {
    _tallView(tester);
    await pumpScreen(tester, const DoctorQrScreen());
    expect(find.byType(QrImageView), findsOneWidget);
    String qrData() => tester
        .widget<SelectableText>(
          find.byType(SelectableText, skipOffstage: false),
        )
        .data!;

    await tester.tap(find.text('QR matni'));
    await tester.pumpAndSettle();
    expect(qrData(), contains('Qon guruhi: A(II) Rh+'));
    expect(qrData(), isNot(contains('Tahlillar:')));

    await tester.tap(find.text('Qon guruhi'));
    await tester.tap(find.text('Oxirgi tahlillar'));
    await tester.pumpAndSettle();
    expect(qrData(), isNot(contains('Qon guruhi')));
    expect(qrData(), contains('Tahlillar:'));
  });

  testWidgets('family: add, edit and delete a member (fake mode)', (
    tester,
  ) async {
    final container = await _openProfileTab(tester);
    List<FamilyMember> family() => container.read(fakeFamilyProvider);
    expect(family(), hasLength(3));

    await tester.tap(find.text('Qo‘shish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pumpAndSettle();
    expect(find.text('Ismni kiriting'), findsOneWidget);
    expect(find.text('Tanlang'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Jasur');
    await tester.tap(find.text('Kim bo‘ladi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('O‘g‘li').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '2019');
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pumpAndSettle();

    final age = DateTime.now().year - 2019;
    expect(find.text('Jasur, $age'), findsOneWidget);
    expect(family().last.relation, 'o‘g‘li');

    // Edit
    await tester.tap(find.text('Jasur, $age'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Jasurbek');
    // Phone for «Qoʻngʻiroq qilish» on /family: checked, then saved.
    final phone = find.byKey(const ValueKey('member-phone'));
    await tester.enterText(phone, '12');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pumpAndSettle();
    expect(find.text('Telefon raqami noto‘g‘ri'), findsOneWidget);
    await tester.enterText(phone, '+998 97 111 22 33');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pumpAndSettle();
    expect(find.text('Jasurbek, $age'), findsOneWidget);
    expect(family(), hasLength(4));
    expect(family().last.phone, '+998 97 111 22 33');
    expect(family().last.dialable, '+998971112233');

    // Delete
    await tester.tap(find.text('Jasurbek, $age'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Jasurbekni o‘chirasizmi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'O‘chirish'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jasurbek'), findsNothing);
    expect(family(), hasLength(3));
  });

  testWidgets('edit profile: blood type and allergies saved', (tester) async {
    final container = await _openProfileTab(tester);
    await tester.tap(find.text('Aziz'));
    await tester.pumpAndSettle();
    expect(find.text('Profilni tahrirlash'), findsOneWidget);

    await tester.tap(find.text('A(II) Rh+'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B(III) Rh-').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      'Penitsillin, yong‘oq',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pumpAndSettle();

    final saved = container.read(fakeProfileProvider);
    expect(saved.bloodType, 'B(III) Rh-');
    expect(saved.allergies, ['Penitsillin', 'yong‘oq']);
    expect(find.text('Elektron tibbiy karta'), findsOneWidget);
    expect(find.text('B(III) Rh-'), findsOneWidget);
  });

  testWidgets('settings: theme and language (saved to the profile)', (
    tester,
  ) async {
    final container = await _openProfileTab(tester);
    await tester.tap(find.text('Qorong‘i'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byType(ProfileScreen))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();
    expect(container.read(appLangProvider), AppLang.ru);
    expect(container.read(fakeProfileProvider).lang, 'ru');
    expect(find.text('Настройки'), findsOneWidget);
  });

  testWidgets('dev mode: hidden until 7 taps on version, then seeds', (
    tester,
  ) async {
    await pumpScreen(tester, const ProfileScreen());
    const seedLabel = 'Namuna ma’lumotlarni yuklash';
    expect(find.text(seedLabel), findsNothing);

    final version = find.textContaining('Sino · v');
    await tester.scrollUntilVisible(version, 200);
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.tap(version);
    }
    await tester.pumpAndSettle();
    expect(find.text(seedLabel), findsNothing);

    await tester.tap(version);
    await tester.pumpAndSettle();
    expect(find.text('Dasturchi rejimi yoqildi'), findsOneWidget);

    final seed = find.text(seedLabel);
    await tester.scrollUntilVisible(seed, 200);
    await tester.pumpAndSettle();
    await tester.tap(seed);
    // Result replaces the «dev mode on» snackbar right away (~0.5 s).
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(
      find.text(
        'Yuklandi: oila — 3, tibbiy karta — 8, tahlillar — 7, '
        'oila dorilari — 2.',
      ),
      findsOneWidget,
    );
  });
}
