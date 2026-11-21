import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/nutrition/application/water_reminders.dart';
import 'package:sino/features/nutrition/data/water_notifications.dart';
import 'package:sino/features/nutrition/presentation/widgets/water_card.dart';

/// Records every call.
class _Notifications implements WaterNotifications {
  final log = <String>[];
  bool grant = true;

  @override
  Future<bool> requestPermission() async {
    log.add('ask');
    return grant;
  }

  @override
  Future<void> scheduleDaily(
    List<int> hours, {
    required String title,
    required String body,
  }) async {
    log.add('daily ${hours.join(',')} | $title | $body');
  }

  @override
  Future<void> cancel() async => log.add('cancel');
}

void main() {
  test('every 2 hours from 9:00 to 21:00', () {
    expect(waterReminderHours, [9, 11, 13, 15, 17, 19, 21]);
  });

  group('WaterRemindersNotifier', () {
    late SharedPreferences prefs;
    late _Notifications n;
    late ProviderContainer c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      n = _Notifications();
      c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          waterNotificationsProvider.overrideWithValue(n),
        ],
      );
      addTearDown(c.dispose);
    });

    test('on by default: asks once, schedules once', () async {
      expect(c.read(waterRemindersProvider), isTrue);
      final notifier = c.read(waterRemindersProvider.notifier);
      await notifier.askOnce();
      await notifier.askOnce();
      expect(n.log, [
        'ask',
        'daily 9,11,13,15,17,19,21 | Suv ichish vaqti 💧 | '
            'Bir stakan suv iching — kuniga 8 stakan',
      ]);
    });

    test('a new language reschedules with its text', () async {
      final notifier = c.read(waterRemindersProvider.notifier);
      await notifier.sync();
      await c.read(appLangProvider.notifier).set(AppLang.ru);
      await notifier.sync();
      expect(n.log, hasLength(2));
      expect(n.log.last, contains('Время выпить воды'));
    });

    test('off cancels and stays off; on asks for permission', () async {
      final notifier = c.read(waterRemindersProvider.notifier);
      await notifier.setEnabled(false);
      expect(prefs.getBool(WaterRemindersNotifier.key), isFalse);
      await notifier.askOnce(); // off: no prompt, nothing scheduled
      expect(n.log, ['cancel']);

      n.grant = false;
      expect(await notifier.setEnabled(true), isFalse);
      expect(n.log, ['cancel', 'ask', startsWith('daily ')]);
    });
  });

  testWidgets('the bell on the water card turns the reminders off and on', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'core.fake_signed_in': true});
    final prefs = await SharedPreferences.getInstance();
    final n = _Notifications();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appOverrides(prefs: prefs, useFake: true),
          waterNotificationsProvider.overrideWithValue(n),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: AppLang.uz.locale,
          supportedLocales: AppLang.locales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: WaterCard(day: DateTime.now())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Shown for the first time: asked and scheduled.
    expect(n.log, ['ask', startsWith('daily ')]);

    final bell = find.byKey(const Key('nutrition-water-notify'));
    expect(tester.widget<IconButton>(bell).isSelected, isTrue);
    await tester.tap(bell);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(bell).isSelected, isFalse);
    expect(n.log.last, 'cancel');
    expect(find.text('Suv eslatmalari o‘chirildi'), findsOneWidget);

    await tester.tap(bell);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(bell).isSelected, isTrue);
    expect(n.log.last, startsWith('daily '));
    expect(
      find.text('Suv eslatmalari yoqildi: har 2 soatda, 9:00–21:00'),
      findsOneWidget,
    );
  });
}
