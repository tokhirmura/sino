import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/storage/prefs.dart';
import '../data/water_notifications.dart';

/// Every 2 hours from 9:00 to 21:00 (S2-7).
const waterReminderHours = [9, 11, 13, 15, 17, 19, 21];

/// Title and body of a water notification.
(String, String) waterNotificationText(AppLang lang) => switch (lang) {
  AppLang.uz => (
    'Suv ichish vaqti 💧',
    'Bir stakan suv iching — kuniga 8 stakan',
  ),
  AppLang.ru => ('Время выпить воды 💧', 'Выпейте стакан воды — 8 в день'),
  AppLang.en => ('Time for water 💧', 'Drink a glass of water — 8 a day'),
};

/// «Water reminders» setting (S2-7), on by default, kept in prefs: daily
/// notifications at [waterReminderHours].
class WaterRemindersNotifier extends Notifier<bool> {
  static const key = 'nutrition.water_notify';

  /// Permission was asked once (the first time the water card was shown).
  static const askedKey = 'nutrition.water_notify_asked';

  /// What is scheduled now (the language or `off`): the card does not
  /// reschedule on every build.
  static const lastKey = 'nutrition.water_notify_last';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(key) ?? true;

  WaterNotifications get _notifications => ref.read(waterNotificationsProvider);

  /// Turns the reminders on (asking for permission) or off. `false` — on,
  /// but the OS denied notifications.
  Future<bool> setEnabled(bool on) async {
    final prefs = ref.read(sharedPreferencesProvider);
    state = on;
    await prefs.setBool(key, on);
    var granted = true;
    if (on) {
      await prefs.setBool(askedKey, true);
      granted = await _notifications.requestPermission();
    }
    await sync();
    return granted;
  }

  /// The first time: asks for permission once (on by default), then
  /// schedules; later only reschedules when the language changed.
  Future<void> askOnce() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (state && prefs.getBool(askedKey) != true) {
      await prefs.setBool(askedKey, true);
      await _notifications.requestPermission();
    }
    await sync();
  }

  Future<void> sync() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final lang = ref.read(appLangProvider);
    final sig = state ? lang.name : 'off';
    if (prefs.getString(lastKey) == sig) return;
    await prefs.setString(lastKey, sig);
    if (!state) {
      await _notifications.cancel();
      return;
    }
    final (title, body) = waterNotificationText(lang);
    await _notifications.scheduleDaily(
      waterReminderHours,
      title: title,
      body: body,
    );
  }
}

final waterRemindersProvider = NotifierProvider<WaterRemindersNotifier, bool>(
  WaterRemindersNotifier.new,
);
