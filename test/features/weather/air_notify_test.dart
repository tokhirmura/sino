import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/weather/application/air_notify.dart';
import 'package:sino/features/weather/application/weather_logic.dart';
import 'package:sino/features/weather/data/air_notifications.dart';
import 'package:sino/features/weather/data/models.dart';
import 'package:sino/features/weather/data/weather_repository.dart';
import 'package:sino/features/weather/presentation/weather_screen.dart';

/// Records every call.
class _Notifications implements AirNotifications {
  final log = <String>[];
  bool grant = true;

  @override
  Future<bool> requestPermission() async {
    log.add('ask');
    return grant;
  }

  @override
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  }) async {
    log.add('schedule $at | $title | $body');
  }

  @override
  Future<void> cancel() async => log.add('cancel');
}

List<AqiHour> _hours(DateTime from, List<int> aqi) => [
  for (var i = 0; i < aqi.length; i++)
    AqiHour(from.add(Duration(hours: i)), aqi[i]),
];

WeatherReport _report(List<AqiHour> airHours) => WeatherReport(
  place: cityById('tashkent')!,
  fetchedAt: DateTime(2026, 11, 21, 12),
  current: CurrentWeather.fromJson({
    'time': '2026-11-21T12:00',
    'temperature_2m': 10,
    'apparent_temperature': 8,
    'relative_humidity_2m': 50,
    'weather_code': 0,
    'wind_speed_10m': 5,
    'is_day': 1,
  }),
  hours: const [],
  days: const [],
  airHours: airHours,
);

void main() {
  group('morningAirAlert', () {
    // Tomorrow 00:00 … 23:00: dirty only 07–09.
    final tomorrow = DateTime(2026, 11, 22);
    final dirtyMorning = _hours(tomorrow, [
      for (var h = 0; h < 24; h++) h >= 7 && h < 10 ? 120 + h : 180,
    ]);

    test('afternoon → tomorrow 07:30, worst AQI of 07:00–10:00', () {
      final a = morningAirAlert(dirtyMorning, DateTime(2026, 11, 21, 15));
      expect(a?.at, DateTime(2026, 11, 22, 7, 30));
      expect(a?.aqi, 129); // 9 o'clock; 10 o'clock (180) is outside
    });

    test('early morning → today 07:30', () {
      final today = _hours(DateTime(2026, 11, 21), List.filled(24, 140));
      final a = morningAirAlert(today, DateTime(2026, 11, 21, 6, 10));
      expect(a?.at, DateTime(2026, 11, 21, 7, 30));
      expect(a?.aqi, 140);
      // 07:30 itself is past: the next morning (no forecast → none).
      expect(morningAirAlert(today, DateTime(2026, 11, 21, 7, 30)), isNull);
    });

    test('clean morning or no forecast → no alert', () {
      final clean = _hours(tomorrow, [
        for (var h = 0; h < 24; h++) h >= 7 && h < 10 ? 100 : 200,
      ]);
      expect(morningAirAlert(clean, DateTime(2026, 11, 21, 15)), isNull);
      expect(morningAirAlert(const [], DateTime(2026, 11, 21, 15)), isNull);
    });
  });

  group('hourly AQI in the report', () {
    test('parsed from Open-Meteo and kept in the cache', () {
      final r = WeatherReport.fromOpenMeteo(
        place: cityById('tashkent')!,
        fetchedAt: DateTime(2026, 11, 21, 12),
        forecast: {
          'current': {
            'time': '2026-11-21T12:00',
            'temperature_2m': 10,
            'weather_code': 0,
          },
        },
        air: {
          'current': {'us_aqi': 90},
          'hourly': {
            'time': [
              '2026-11-22T07:00',
              '2026-11-22T08:00',
              '2026-11-22T09:00',
            ],
            'us_aqi': [110, null, 130.4],
          },
        },
      );
      expect([for (final h in r.airHours) h.aqi], [110, 130]);
      expect(r.airHours.last.time, DateTime(2026, 11, 22, 9));

      final back = WeatherReport.fromJson(r.toJson());
      expect([for (final h in back.airHours) h.aqi], [110, 130]);
      expect(back.air?.aqi, 90);
    });

    test('the request asks for 2 days of hourly us_aqi', () {
      final q = OpenMeteoWeatherRepository.airUri(cityById('tashkent')!)
          .queryParameters;
      expect(q['hourly'], 'us_aqi');
      expect(q['forecast_days'], '2');
    });

    test('demo: the city AQI for the next 48 hours', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeWeatherRepository(await SharedPreferences.getInstance());
      final r = await repo.report(cityById('tashkent')!);
      expect(r.airHours, hasLength(48));
      expect(r.airHours.every((h) => h.aqi == 135), isTrue);
    });
  });

  group('AirNotifyNotifier', () {
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
          airNotificationsProvider.overrideWithValue(n),
        ],
      );
      addTearDown(c.dispose);
    });

    final now = DateTime(2026, 11, 21, 15);
    final dirty = _report(_hours(DateTime(2026, 11, 22), List.filled(24, 156)));
    final clean = _report(_hours(DateTime(2026, 11, 22), List.filled(24, 40)));

    test('on by default; schedules once, then only on a change', () async {
      final notifier = c.read(airNotifyProvider.notifier);
      expect(c.read(airNotifyProvider), isTrue);

      await notifier.sync(dirty, now: now);
      expect(n.log, [
        'schedule 2026-11-22 07:30:00.000 | Havo ifloslangan (AQI 156) | '
            'Toshkent: bugun uyda mashq qiling',
      ]);
      // The minute refresh with the same forecast: nothing to do.
      await notifier.sync(dirty, now: now);
      expect(n.log, hasLength(1));
      // No report yet — keep what is scheduled.
      await notifier.sync(null, now: now);
      expect(n.log, hasLength(1));

      await notifier.sync(clean, now: now);
      expect(n.log.last, 'cancel');
      await notifier.sync(clean, now: now);
      expect(n.log, hasLength(2));
    });

    test('Russian text follows the app language', () async {
      await c.read(appLangProvider.notifier).set(AppLang.ru);
      await c.read(airNotifyProvider.notifier).sync(dirty, now: now);
      expect(n.log.single, contains('Воздух загрязнён (AQI 156)'));
      expect(n.log.single, contains('Ташкент: сегодня тренируйтесь дома'));
    });

    test('off: cancels and stays off; on: asks for permission', () async {
      final notifier = c.read(airNotifyProvider.notifier);
      await notifier.setEnabled(false, dirty);
      expect(c.read(airNotifyProvider), isFalse);
      expect(prefs.getBool(AirNotifyNotifier.key), isFalse);
      expect(n.log, ['cancel']);
      await notifier.sync(dirty, now: now);
      expect(n.log, ['cancel']);

      n.grant = false;
      expect(await notifier.setEnabled(true, null), isFalse);
      expect(n.log, ['cancel', 'ask']);
    });

    test('askOnce asks only the first time', () async {
      final notifier = c.read(airNotifyProvider.notifier);
      await notifier.askOnce(null);
      await notifier.askOnce(null);
      expect(n.log, ['ask']);
    });
  });

  testWidgets('the switch on the weather screen turns the alert off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'core.fake_signed_in': true});
    final prefs = await SharedPreferences.getInstance();
    final n = _Notifications();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appOverrides(prefs: prefs, useFake: true),
          airNotificationsProvider.overrideWithValue(n),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: AppLang.uz.locale,
          supportedLocales: AppLang.locales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const WeatherScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // First visit: asked once; the demo Tashkent (AQI 135) schedules.
    expect(n.log.where((x) => x == 'ask'), hasLength(1));
    expect(n.log.where((x) => x.startsWith('schedule')), hasLength(1));

    final toggle = find.byKey(const Key('weather-air-notify'));
    expect(tester.widget<Switch>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(prefs.getBool(AirNotifyNotifier.key), isFalse);
    expect(n.log.last, 'cancel');
    expect(find.text('Ertalabki ogohlantirish o‘chirildi'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
