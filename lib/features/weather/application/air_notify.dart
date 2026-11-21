import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/storage/prefs.dart';
import '../data/air_notifications.dart';
import '../data/models.dart';
import 'weather_logic.dart';

/// Title and body of the morning notification: «Havo ifloslangan
/// (AQI 156)» / «Toshkent: bugun uyda mashq qiling».
(String, String) airNotificationText(AppLang lang, int aqi, String place) {
  final where = place.isEmpty ? '' : '$place: ';
  return switch (lang) {
    AppLang.uz => (
      'Havo ifloslangan (AQI $aqi)',
      '${where}bugun uyda mashq qiling',
    ),
    AppLang.ru => (
      'Воздух загрязнён (AQI $aqi)',
      '$whereсегодня тренируйтесь дома',
    ),
    AppLang.en => (
      'The air is polluted (AQI $aqi)',
      '${where}train at home today',
    ),
  };
}

/// «Morning air alert» setting (S2-7), on by default, kept in prefs. While
/// on, every report schedules a notification for the next 07:30 if the
/// forecast AQI of that morning is above 100 (else removes it).
class AirNotifyNotifier extends Notifier<bool> {
  static const key = 'weather.air_notify';

  /// Permission was asked once (the first visit of the weather screen).
  static const askedKey = 'weather.air_notify_asked';

  /// What is scheduled now (`<at>|<aqi>|<lang>` or `none`): the minute
  /// refresh does not touch the plugin when nothing changed.
  static const lastKey = 'weather.air_notify_last';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(key) ?? true;

  AirNotifications get _notifications => ref.read(airNotificationsProvider);

  /// Turns the alert on (asking for permission) or off. `false` — on, but
  /// the OS denied notifications.
  Future<bool> setEnabled(bool on, WeatherReport? report) async {
    final prefs = ref.read(sharedPreferencesProvider);
    state = on;
    await prefs.setBool(key, on);
    var granted = true;
    if (on) {
      await prefs.setBool(askedKey, true);
      granted = await _notifications.requestPermission();
    }
    await sync(report);
    return granted;
  }

  /// On the first visit of the weather screen: asks for permission once
  /// (the alert is on by default), then schedules.
  Future<void> askOnce(WeatherReport? report) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (state && prefs.getBool(askedKey) != true) {
      await prefs.setBool(askedKey, true);
      await _notifications.requestPermission();
    }
    await sync(report);
  }

  /// Schedules or removes the morning notification after a [report].
  Future<void> sync(WeatherReport? report, {DateTime? now}) async {
    // On without a report yet — keep whatever is scheduled.
    if (state && report == null) return;
    final alert = state
        ? morningAirAlert(report!.airHours, now ?? DateTime.now())
        : null;
    final lang = ref.read(appLangProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final sig = alert == null
        ? 'none'
        : '${alert.at.toIso8601String()}|${alert.aqi}|${lang.name}';
    if (prefs.getString(lastKey) == sig) return;
    await prefs.setString(lastKey, sig);
    if (alert == null) {
      await _notifications.cancel();
      return;
    }
    final name = report!.place.name;
    final place = '${name[lang.name] ?? name['uz'] ?? ''}';
    final (title, body) = airNotificationText(lang, alert.aqi, place);
    await _notifications.schedule(at: alert.at, title: title, body: body);
  }
}

final airNotifyProvider = NotifierProvider<AirNotifyNotifier, bool>(
  AirNotifyNotifier.new,
);
