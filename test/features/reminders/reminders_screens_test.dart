import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/reminders/application/reminders_providers.dart';
import 'package:sino/features/reminders/data/models.dart';
import 'package:sino/features/reminders/data/reminder_notifications.dart';
import 'package:sino/features/reminders/presentation/history_screen.dart';
import 'package:sino/features/reminders/presentation/reminder_form_screen.dart';
import 'package:sino/features/reminders/presentation/reminders_paths.dart';
import 'package:sino/features/reminders/presentation/reminders_screen.dart';
import 'package:sino/features/reminders/reminders_feature.dart';

import '../../helpers/test_app.dart';

class _Notifications implements ReminderNotifications {
  int permissionRequests = 0;
  List<Reminder> synced = const [];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> sync(
    List<Reminder> reminders, {
    required AppLang lang,
    Map<String, String> memberNames = const {},
  }) async => synced = reminders;
}

class _Harness {
  final notifications = _Notifications();
  late GoRouter router;
  late ProviderContainer container;
}

Future<_Harness> _pumpRouter(WidgetTester tester, String location) async {
  final h = _Harness();
  final prefs = await fakePrefs(signedIn: true);
  h.router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: location,
    routes: remindersRoutes,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appOverrides(prefs: prefs, useFake: true),
        reminderNotificationsProvider.overrideWithValue(h.notifications),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: AppLang.uz.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: h.router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  h.container = ProviderScope.containerOf(
    tester.element(find.byType(Navigator).first),
  );
  return h;
}

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Finder _inDose(String reminderKey, Finder f) => find.descendant(
  of: find.byKey(ValueKey('dose-fake-rem-$reminderKey')),
  matching: f,
);

void main() {
  testWidgets('today: mark a dose taken and undo it', (tester) async {
    final h = await _pumpRouter(tester, AppRoutes.reminders);
    // Vitamin D3 is every day for the user; no demo log for today.
    final tile = find.byKey(const ValueKey('dose-fake-rem-vitamin_d3'));
    await _scrollTo(tester, tile);
    await tester.tap(_inDose('vitamin_d3', find.text('Ichdim')));
    await tester.pumpAndSettle();
    expect(_inDose('vitamin_d3', find.text('Ichildi')), findsOneWidget);
    final logs = h.container.read(reminderLogsProvider).requireValue;
    final today = dateKey(DateTime.now());
    expect(
      logs.where(
        (l) =>
            l.reminderId == 'fake-rem-vitamin_d3' &&
            dateKey(l.takenAt) == today,
      ),
      hasLength(1),
    );

    await tester.tap(_inDose('vitamin_d3', find.byTooltip('Bekor qilish')));
    await tester.pumpAndSettle();
    expect(_inDose('vitamin_d3', find.text('Ichildi')), findsNothing);
    expect(_inDose('vitamin_d3', find.text('Ichdim')), findsOneWidget);
  });

  testWidgets('member doses show the family member', (tester) async {
    await _pumpRouter(tester, AppRoutes.reminders);
    expect(find.text('Akbar'), findsWidgets); // Amlodipin for the father
    expect(find.text('Malika'), findsWidgets); // Nurofen for the daughter
  });

  testWidgets('pause from the list', (tester) async {
    final h = await _pumpRouter(tester, AppRoutes.reminders);
    await _scrollTo(tester, find.text('To‘xtatilgan'));
    expect(find.text('To‘xtatilgan'), findsOneWidget); // Omeprazol
    final switches = find.byType(Switch);
    // Reminders are sorted by time: Omeprazol 07:30, Amlodipin 08:00, …
    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();
    expect(find.text('To‘xtatilgan'), findsNWidgets(2));
    final rs = h.container.read(remindersProvider).requireValue;
    expect(rs.firstWhere((r) => r.id == 'fake-rem-amlodipine').active, false);
    expect(
      h.notifications.synced
          .firstWhere((r) => r.id == 'fake-rem-amlodipine')
          .active,
      false,
    );
  });

  testWidgets('add: validation, save for a family member, permission once', (
    tester,
  ) async {
    final h = await _pumpRouter(tester, AppRoutes.reminders);
    await tester.tap(find.text('Qo‘shish'));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderFormScreen), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);

    await _scrollTo(tester, find.text('Saqlash'));
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Dori nomini kiriting'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Dori nomini kiriting'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Metformin');
    await tester.enterText(find.byType(TextField).at(1), '500 mg');
    await _scrollTo(tester, find.text('Ish kunlari'));
    await tester.tap(find.text('Ish kunlari'));
    await tester.pump();
    await _scrollTo(tester, find.widgetWithText(ChoiceChip, 'Dilfuza'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Dilfuza'));
    await tester.pump();
    await _scrollTo(tester, find.text('Saqlash'));
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    expect(find.byType(RemindersScreen), findsOneWidget);
    expect(find.text('Eslatma saqlandi'), findsOneWidget);
    final added = h.container
        .read(remindersProvider)
        .requireValue
        .firstWhere((r) => r.name == 'Metformin');
    expect(added.days, [1, 2, 3, 4, 5]);
    expect(added.memberId, 'fake-mother');
    expect(added.dose, '500 mg');
    expect((added.hour, added.minute), (8, 0));
    expect(h.notifications.permissionRequests, 1);

    // A second reminder doesn't ask again.
    await tester.tap(find.text('Qo‘shish'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Aspirin');
    // A focused field scrolls its caret back on screen; drop the focus.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await _scrollTo(tester, find.text('Saqlash'));
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    expect(
      h.container
          .read(remindersProvider)
          .requireValue
          .any((r) => r.name == 'Aspirin'),
      isTrue,
    );
    expect(h.notifications.permissionRequests, 1);
  });

  testWidgets('edit and delete a reminder', (tester) async {
    final h = await _pumpRouter(
      tester,
      RemindersPaths.edit('fake-rem-omeprazole'),
    );
    expect(find.text('Eslatmani tahrirlash'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Omeprazol'), findsOneWidget);
    expect(find.text('07:30'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Omeprazol 20');
    await _scrollTo(tester, find.text('Saqlash'));
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    expect(
      h.container
          .read(remindersProvider)
          .requireValue
          .any((r) => r.name == 'Omeprazol 20'),
      isTrue,
    );

    h.router.push(RemindersPaths.edit('fake-rem-omeprazole'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('O‘chirish'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'O‘chirish'));
    await tester.pumpAndSettle();
    expect(find.text('Eslatmani o‘chirasizmi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'O‘chirish'));
    await tester.pumpAndSettle();
    expect(find.text('Eslatma o‘chirildi'), findsOneWidget);
    expect(
      h.container
          .read(remindersProvider)
          .requireValue
          .any((r) => r.id == 'fake-rem-omeprazole'),
      isFalse,
    );
  });

  testWidgets('unknown reminder id', (tester) async {
    await _pumpRouter(tester, RemindersPaths.edit('nope'));
    expect(find.text('Eslatma topilmadi'), findsOneWidget);
  });

  testWidgets('history: logs matched to doses by reminder and date', (
    tester,
  ) async {
    await _pumpRouter(tester, RemindersPaths.history);
    expect(find.byType(IntakeHistoryScreen), findsOneWidget);
    expect(find.text('So‘nggi 7 kun'), findsOneWidget);
    await _scrollTo(tester, find.text('Kecha'));
    // Yesterday's demo logs: Amlodipin 08:04, Vitamin D3 09:10,
    // Nurofen 20:05 — each shown on its own dose.
    await _scrollTo(tester, find.text('08:04 da'));
    expect(find.text('08:04 da'), findsOneWidget);
    await _scrollTo(tester, find.text('20:05 da'));
    expect(find.text('20:05 da'), findsOneWidget);
  });

  testWidgets('home card shows the next dose', (tester) async {
    final prefs = await fakePrefs(signedIn: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(prefs: prefs, useFake: true),
        child: MaterialApp(
          locale: AppLang.uz.locale,
          supportedLocales: AppLang.locales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Builder(builder: remindersHomeCards.single.builder),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Eslatmalar'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^(Keyingi|Hozir): ')), findsOneWidget);
  });

  final screens = <String, Widget Function()>{
    'list': () => const RemindersScreen(),
    'new': () => const ReminderFormScreen(),
    'edit': () => const ReminderFormScreen(reminderId: 'fake-rem-amlodipine'),
    'history': () => const IntakeHistoryScreen(),
    'home card': () => Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [Builder(builder: remindersHomeCards.single.builder)],
      ),
    ),
  };
  for (final MapEntry(key: name, value: build) in screens.entries) {
    for (final lang in AppLang.values) {
      for (final dark in [false, true]) {
        testWidgets('$name · ${lang.name} · ${dark ? 'dark' : 'light'}', (
          tester,
        ) async {
          // Smallest common phone + enlarged system font.
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final prefs = await fakePrefs(signedIn: true);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...appOverrides(prefs: prefs, useFake: true),
                reminderNotificationsProvider.overrideWithValue(
                  _Notifications(),
                ),
              ],
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                locale: lang.locale,
                supportedLocales: AppLang.locales,
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: build(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
