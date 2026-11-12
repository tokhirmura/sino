import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/backend/backend.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/onboarding/application/auth_errors.dart';
import 'package:sino/features/onboarding/application/onboarding_prefs.dart';
import 'package:sino/features/onboarding/data/auth_repository.dart';
import 'package:sino/features/onboarding/onboarding_feature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Always fails with [error] — to check error texts.
class _FailingAuthRepository implements AuthRepository {
  _FailingAuthRepository(this.error);
  final Object error;

  @override
  Future<void> signInAnonymously({required String lang}) async => throw error;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async => throw error;

  @override
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String lang,
  }) async => throw error;
}

/// Full app in fake mode, signed out, with custom prefs / overrides.
Future<ProviderContainer> _pumpSignedOut(
  WidgetTester tester, {
  bool introSeen = false,
  AuthRepository? auth,
}) async {
  SharedPreferences.setMockInitialValues({
    if (introSeen) IntroSeenNotifier.key: true,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appOverrides(prefs: prefs, useFake: true),
        if (auth != null) authRepositoryProvider.overrideWithValue(auth),
      ],
      child: const SinoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _skipIntro(WidgetTester tester) =>
    _tap(tester, find.text('O‘tkazib yuborish'));

void main() {
  test('onboarding exposes its root route', () {
    final paths = [
      for (final r in onboardingRoutes.whereType<GoRoute>()) r.path,
    ];
    expect(paths, contains(AppRoutes.onboarding));
  });

  test('auth errors are classified', () {
    expect(
      authErrorKind(const AuthApiException('x', code: 'invalid_credentials')),
      AuthErrorKind.invalidCredentials,
    );
    expect(
      authErrorKind(const AuthApiException('x', code: 'user_already_exists')),
      AuthErrorKind.userExists,
    );
    expect(
      authErrorKind(
        const AuthApiException('x', code: 'anonymous_provider_disabled'),
      ),
      AuthErrorKind.anonymousDisabled,
    );
    expect(
      authErrorKind(const AuthApiException('x', statusCode: '429')),
      AuthErrorKind.rateLimited,
    );
    expect(authErrorKind(AuthRetryableFetchException()), AuthErrorKind.network);
    expect(
      authErrorKind(const SocketException('offline')),
      AuthErrorKind.network,
    );
    expect(authErrorKind(StateError('?')), AuthErrorKind.unknown);
  });

  testWidgets('3 intro slides → sign-in options, intro remembered', (
    tester,
  ) async {
    final container = await _pumpSignedOut(tester);
    expect(find.text('Sog‘lig‘ingiz — bitta ilovada'), findsOneWidget);

    await _tap(tester, find.text('Keyingi'));
    expect(find.text('Dorini tez toping'), findsOneWidget);
    await _tap(tester, find.text('Keyingi'));
    expect(find.text('Tibbiy kartangiz doim yoningizda'), findsOneWidget);
    await _tap(tester, find.text('Boshlash'));

    expect(find.text('Kirish usulini tanlang'), findsOneWidget);
    expect(find.text('OneID orqali kirish'), findsOneWidget);
    expect(find.text('Email orqali kirish'), findsOneWidget);
    expect(find.text('Mehmon sifatida davom etish'), findsOneWidget);
    expect(container.read(introSeenProvider), isTrue);
  });

  testWidgets('intro already seen → starts on sign-in options', (tester) async {
    await _pumpSignedOut(tester, introSeen: true);
    expect(find.text('Kirish usulini tanlang'), findsOneWidget);
  });

  testWidgets('language switch translates onboarding', (tester) async {
    await _pumpSignedOut(tester, introSeen: true);
    await _tap(tester, find.text('RU'));
    expect(find.text('Выберите способ входа'), findsOneWidget);
    await _tap(tester, find.text('EN'));
    expect(find.text('Continue as guest'), findsOneWidget);
  });

  testWidgets('guest → signed in (fake flag) → home', (tester) async {
    final container = await _pumpSignedOut(tester);
    await _skipIntro(tester);
    await _tap(tester, find.text('Mehmon sifatida davom etish'));

    expect(container.read(fakeAuthProvider), isTrue);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('email: validation, then sign in → home', (tester) async {
    final container = await _pumpSignedOut(tester, introSeen: true);
    await _tap(tester, find.text('Email orqali kirish'));

    final submit = find.widgetWithText(FilledButton, 'Kirish');
    await _tap(tester, submit);
    expect(find.text('To‘g‘ri email kiriting'), findsOneWidget);
    expect(find.text('Kamida 6 ta belgi'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'a@sino.uz');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret12');
    await _tap(tester, submit);

    expect(container.read(fakeAuthProvider), isTrue);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('email: sign-up mode → home', (tester) async {
    await _pumpSignedOut(tester, introSeen: true);
    await _tap(tester, find.text('Email orqali kirish'));
    await _tap(tester, find.text('Ro‘yxatdan o‘tish'));

    await tester.enterText(find.byType(TextFormField).at(0), 'b@sino.uz');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret12');
    await _tap(tester, find.text('Hisob yaratish'));

    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('email: server error → readable text, stays on form', (
    tester,
  ) async {
    await _pumpSignedOut(
      tester,
      introSeen: true,
      auth: _FailingAuthRepository(
        const AuthApiException('Invalid', code: 'invalid_credentials'),
      ),
    );
    await _tap(tester, find.text('Email orqali kirish'));
    await tester.enterText(find.byType(TextFormField).at(0), 'a@sino.uz');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-pass');
    await _tap(tester, find.widgetWithText(FilledButton, 'Kirish'));

    expect(find.text('Email yoki parol noto‘g‘ri.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('guest: network error → snackbar text', (tester) async {
    await _pumpSignedOut(
      tester,
      introSeen: true,
      auth: _FailingAuthRepository(AuthRetryableFetchException()),
    );
    await _tap(tester, find.text('Mehmon sifatida davom etish'));
    expect(
      find.text(
        'Internet aloqasi yo‘q. Tarmoqni tekshirib, qayta urinib ko‘ring.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('email: back arrow returns to options', (tester) async {
    await _pumpSignedOut(tester, introSeen: true);
    await _tap(tester, find.text('Email orqali kirish'));
    await _tap(tester, find.byIcon(Icons.arrow_back));
    expect(find.text('Kirish usulini tanlang'), findsOneWidget);
  });

  testWidgets('OneID: biometrics → verified data → consent → home', (
    tester,
  ) async {
    final container = await _pumpSignedOut(tester, introSeen: true);
    await tester.tap(find.text('OneID orqali kirish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Biometrik tekshiruv…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Profil davlat tomonidan tasdiqlangan'), findsOneWidget);
    expect(find.text('Aziz Karimov'), findsOneWidget);
    expect(find.text('14 ta yozuv'), findsOneWidget);
    expect(find.text('2 ta faol'), findsOneWidget);

    final continueBtn = find.widgetWithText(FilledButton, 'Davom etish');
    await tester.ensureVisible(continueBtn);
    expect(tester.widget<FilledButton>(continueBtn).onPressed, isNull);
    expect(container.read(fakeAuthProvider), isFalse);

    await _tap(tester, find.byType(CheckboxListTile));
    await _tap(tester, continueBtn);

    expect(container.read(fakeAuthProvider), isTrue);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
