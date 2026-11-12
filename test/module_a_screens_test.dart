// P1-6: every module A screen in uz / ru / en × light / dark on a small
// phone — no layout overflow, and no Uzbek UI strings left in ru / en.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/assistant/presentation/assistant_screen.dart';
import 'package:sino/features/home/presentation/home_screen.dart';
import 'package:sino/features/onboarding/presentation/profile_setup_screen.dart';
import 'package:sino/features/onboarding/presentation/widgets/email_auth_view.dart';
import 'package:sino/features/onboarding/presentation/widgets/intro_slides.dart';
import 'package:sino/features/onboarding/presentation/widgets/one_id_view.dart';
import 'package:sino/features/onboarding/presentation/widgets/sign_in_options.dart';
import 'package:sino/features/profile/presentation/doctor_qr_screen.dart';
import 'package:sino/features/profile/presentation/edit_profile_screen.dart';
import 'package:sino/features/profile/presentation/family_member_screen.dart';
import 'package:sino/features/profile/presentation/lab_results_screen.dart';
import 'package:sino/features/profile/presentation/medical_records_screen.dart';
import 'package:sino/features/profile/presentation/profile_screen.dart';
import 'package:sino/features/sos/presentation/first_aid_screen.dart';
import 'package:sino/features/sos/presentation/sos_screen.dart';

import 'helpers/test_app.dart';

Widget _body(Widget child) => Scaffold(body: SafeArea(child: child));

/// Screens; `data: true` — shows DB/asset texts (Uzbek by nature), so the
/// «no Uzbek in ru/en» check is skipped.
final _screens = <String, (Widget Function(), {bool data})>{
  'intro': (() => _body(IntroSlides(onDone: () {})), data: false),
  'sign-in options': (
    () => _body(
      SignInOptions(
        onOneId: () {},
        onEmail: () {},
        onGuest: () {},
        guestLoading: false,
      ),
    ),
    data: false,
  ),
  'email': (() => _body(EmailAuthView(onBack: () {})), data: false),
  'oneid': (() => _body(OneIdView(onBack: () {})), data: true),
  'profile setup': (() => const ProfileSetupScreen(), data: false),
  'home': (() => const HomeScreen(), data: false),
  'profile': (() => const ProfileScreen(), data: true),
  'edit profile': (() => const EditProfileScreen(), data: false),
  'family form': (() => const FamilyMemberScreen(), data: false),
  'medical records': (() => const MedicalRecordsScreen(), data: true),
  'lab results': (() => const LabResultsScreen(), data: false),
  'doctor qr': (() => const DoctorQrScreen(), data: false),
  'sos': (() => const SosScreen(), data: false),
  'assistant': (() => const AssistantScreen(), data: false),
  for (final id in ['cpr', 'choking', 'bleeding', 'burns', 'stroke', 'heat'])
    'first aid $id': (() => FirstAidScreen(id: id), data: false),
};

/// Uzbek Latin letters o‘ / g‘ (U+2018) — never in Russian or English.
final _uzbek = RegExp('[oOgG]‘');

void main() {
  for (final MapEntry(key: name, value: (build, data: data))
      in _screens.entries) {
    for (final lang in AppLang.values) {
      for (final dark in [false, true]) {
        final label = '$name · ${lang.name} · ${dark ? 'dark' : 'light'}';
        testWidgets(label, (tester) async {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final prefs = await fakePrefs(signedIn: true);
          await tester.pumpWidget(
            ProviderScope(
              overrides: appOverrides(prefs: prefs, useFake: true),
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                locale: lang.locale,
                supportedLocales: AppLang.locales,
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: build(),
              ),
            ),
          );
          // OneID «biometrics» takes ~2 s.
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          // Overflow errors fail the test by themselves (with details).

          if (lang != AppLang.uz && !data) {
            final uzbek = [
              for (final t in tester.widgetList<Text>(find.byType(Text)))
                if (_uzbek.hasMatch(t.data ?? t.textSpan?.toPlainText() ?? ''))
                  t.data ?? t.textSpan!.toPlainText(),
            ];
            expect(uzbek, isEmpty, reason: '$label: untranslated');
          }
        });
      }
    }
  }
}
