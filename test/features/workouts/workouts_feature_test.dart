import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/workouts/data/workouts_repository.dart';
import 'package:sino/features/workouts/presentation/widgets/plan_day_card.dart';
import 'package:sino/features/workouts/presentation/workouts_screen.dart';
import 'package:sino/features/workouts/workouts_feature.dart';

import '../../helpers/test_app.dart';

/// A new [UniqueKey] = a fresh ProviderContainer (an app restart).
Future<void> _start(WidgetTester tester, SharedPreferences prefs) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: appOverrides(prefs: prefs, useFake: true),
      child: MaterialApp(
        theme: AppTheme.light,
        locale: AppLang.uz.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const WorkoutsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  test('workouts exposes its root route', () {
    final paths = [for (final r in workoutsRoutes.whereType<GoRoute>()) r.path];
    expect(paths, contains(AppRoutes.workouts));
  });

  testWidgets('build a plan, keep it after restart, rebuild with new params', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final prefs = await fakePrefs(signedIn: true);
    await _start(tester, prefs);

    // No plan yet → the generator form.
    expect(find.text('Mashg‘ulot rejangizni tuzamiz'), findsOneWidget);
    expect(find.textContaining('Shifokor maslahatini'), findsOneWidget);

    await _tapVisible(tester, find.byKey(const Key('workouts-type-home')));
    await _tapVisible(tester, find.byKey(const Key('workouts-goal-lose')));
    await _tapVisible(tester, find.byKey(const Key('workouts-days-2')));
    await _tapVisible(tester, find.byKey(const Key('workouts-generate')));

    expect(find.text('Haftalik reja'), findsOneWidget);
    expect(find.byType(PlanDayCard), findsNWidgets(2));
    expect(find.text('Dushanba'), findsOneWidget);
    expect(find.text('Payshanba'), findsOneWidget);
    expect(
      find.text('Arqon sakrash'),
      findsWidgets,
    ); // jump rope — cardio first
    expect(prefs.getString(FakeWorkoutsRepository.planKey), isNotNull);
    final firstTotal = tester
        .widget<Text>(find.byKey(const Key('workouts-week-total')))
        .data;

    // Restart: the saved plan is shown.
    await _start(tester, prefs);
    expect(find.byType(PlanDayCard), findsNWidgets(2));

    // New plan: gym, mass, 6 days.
    await _tapVisible(tester, find.byKey(const Key('workouts-new-plan')));
    await _tapVisible(tester, find.byKey(const Key('workouts-type-gym')));
    await _tapVisible(tester, find.byKey(const Key('workouts-goal-gain')));
    await _tapVisible(tester, find.byKey(const Key('workouts-days-6')));
    await _tapVisible(tester, find.byKey(const Key('workouts-generate')));

    expect(find.text('Yangi reja tayyor'), findsOneWidget);
    expect(find.byType(PlanDayCard), findsNWidgets(6));
    expect(find.text('Shanba'), findsOneWidget);
    expect(find.text('Arqon sakrash'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('workouts-week-total'))).data,
      isNot(firstTotal),
    );
  });
}
