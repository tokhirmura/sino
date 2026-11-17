import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/core/backend/backend.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/features/weather/application/weather_logic.dart';
import 'package:sino/features/weather/application/weather_providers.dart';
import 'package:sino/features/weather/data/models.dart';
import 'package:sino/features/weather/data/weather_repository.dart';

final _tashkent = weatherCities.first;
final _samarkand = cityById('samarkand')!;

/// Open-Meteo-shaped answer: current 14:30, hourly from 00:00 for 2 days.
Map<String, dynamic> _forecast({int code = 3, double temp = 11.4}) => {
  'current': {
    'time': '2026-11-18T14:30',
    'temperature_2m': temp,
    'apparent_temperature': temp - 2,
    'relative_humidity_2m': 64,
    'weather_code': code,
    'wind_speed_10m': 6.1,
    'is_day': 1,
  },
  'hourly': {
    'time': [
      for (var i = 0; i < 48; i++)
        DateTime(2026, 11, 18, i).toIso8601String().substring(0, 16),
    ],
    'temperature_2m': [for (var i = 0; i < 48; i++) i.toDouble()],
    'weather_code': [for (var i = 0; i < 48; i++) i < 16 ? 3 : 61],
    'precipitation_probability': [for (var i = 0; i < 48; i++) i < 16 ? 0 : 80],
  },
  'daily': {
    'time': ['2026-11-18', '2026-11-19'],
    'weather_code': [3, 61],
    'temperature_2m_max': [15.2, 13.0],
    'temperature_2m_min': [4.1, 6.0],
    'precipitation_probability_max': [10, 80],
    'uv_index_max': [2.5, 1.1],
  },
};

Map<String, dynamic> _air(int aqi) => {
  'current': {
    'time': '2026-11-18T14:00',
    'us_aqi': aqi,
    'pm2_5': 49.8,
    'pm10': 71.2,
  },
};

/// Answers by host; [down] = no network.
MockClient _client({int aqi = 135, bool down = false, bool airDown = false}) =>
    MockClient((req) async {
      if (down) throw const SocketException('Network is unreachable');
      if (req.url.host.startsWith('air-quality')) {
        if (airDown) return http.Response('oops', 500);
        return http.Response(jsonEncode(_air(aqi)), 200);
      }
      return http.Response(jsonEncode(_forecast()), 200);
    });

Future<SharedPreferences> _prefs([Map<String, Object> v = const {}]) async {
  SharedPreferences.setMockInitialValues(v);
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parsing', () {
    test('Open-Meteo answer → report; hours start at the current hour', () {
      final r = WeatherReport.fromOpenMeteo(
        place: _tashkent,
        forecast: _forecast(),
        air: _air(135),
        fetchedAt: DateTime(2026, 11, 18, 14, 31),
      );
      expect(r.current.temp, 11.4);
      expect(r.current.code, 3);
      expect(r.hours, hasLength(24));
      expect(r.hours.first.time, DateTime(2026, 11, 18, 14));
      expect(r.hours.first.temp, 14);
      expect(r.days, hasLength(2));
      expect(r.days[1].precipChance, 80);
      expect(r.air!.aqi, 135);
      expect(r.air!.pm25, 49.8);
    });

    test('cache round-trip keeps everything', () {
      final r = WeatherReport.fromOpenMeteo(
        place: _samarkand,
        forecast: _forecast(),
        air: _air(58),
        fetchedAt: DateTime(2026, 11, 18, 14, 31),
      );
      final back = WeatherReport.fromJson(
        jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
      );
      expect(back.place.id, 'samarkand');
      expect(back.fetchedAt, r.fetchedAt);
      expect(back.current.temp, r.current.temp);
      expect(back.hours.length, r.hours.length);
      expect(back.hours.first.time, r.hours.first.time);
      expect(back.days.last.max, 13.0);
      expect(back.air!.aqi, 58);
    });

    test('no air quality → air is null', () {
      final r = WeatherReport.fromOpenMeteo(
        place: _tashkent,
        forecast: _forecast(),
        fetchedAt: DateTime(2026, 11, 18),
      );
      expect(r.air, isNull);
    });

    test('the nearest city names «my location»', () {
      expect(nearestCity(41.311, 69.280).id, 'tashkent');
      expect(nearestCity(39.65, 66.97).id, 'samarkand');
      expect(distanceKm(41.2995, 69.2401, 39.6542, 66.9597), closeTo(265, 10));
    });
  });

  group('logic', () {
    test('AQI levels', () {
      expect(AqiLevel.of(50), AqiLevel.good);
      expect(AqiLevel.of(51), AqiLevel.moderate);
      expect(AqiLevel.of(100), AqiLevel.moderate);
      expect(AqiLevel.of(101), AqiLevel.sensitive);
      expect(AqiLevel.of(151), AqiLevel.unhealthy);
      expect(AqiLevel.of(201), AqiLevel.veryUnhealthy);
      expect(AqiLevel.of(301), AqiLevel.hazardous);
    });

    WeatherReport report({int? aqi, int code = 0, double feels = 15}) =>
        WeatherReport(
          place: _tashkent,
          fetchedAt: DateTime(2026, 11, 18),
          current: CurrentWeather(
            time: DateTime(2026, 11, 18, 12),
            temp: feels,
            feelsLike: feels,
            humidity: 40,
            wind: 5,
            code: code,
          ),
          hours: [
            HourWeather(
              time: DateTime(2026, 11, 18, 12),
              temp: feels,
              code: code,
            ),
          ],
          days: const [],
          air: aqi == null ? null : AirQuality(aqi: aqi),
        );

    test('tips', () {
      expect(weatherTips(report()), [WeatherTip.goodDay]);
      expect(outdoorOk(report()), isTrue);
      expect(weatherTips(report(aqi: 135)).first, WeatherTip.airSensitive);
      expect(outdoorOk(report(aqi: 135)), isFalse);
      expect(weatherTips(report(aqi: 180)).first, WeatherTip.airBad);
      expect(weatherTips(report(aqi: 100)), [WeatherTip.goodDay]);
      expect(weatherTips(report(code: 61)), contains(WeatherTip.rain));
      expect(weatherTips(report(feels: 36)), contains(WeatherTip.heat));
      expect(weatherTips(report(feels: -3)), contains(WeatherTip.cold));
    });
  });

  group('Open-Meteo repository', () {
    test('fresh answer is cached; offline → the cached one', () async {
      final prefs = await _prefs();
      final online = OpenMeteoWeatherRepository(_client(), prefs);
      final r = await online.report(_tashkent);
      expect(r.fromCache, isFalse);
      expect(r.air!.aqi, 135);
      expect(online.cached('tashkent'), isNotNull);

      final offline = OpenMeteoWeatherRepository(_client(down: true), prefs);
      final c = await offline.report(_tashkent);
      expect(c.fromCache, isTrue);
      expect(c.place.id, 'tashkent');
      expect(c.current.temp, r.current.temp);
      expect(c.air!.aqi, 135);
    });

    test(
      'offline, nothing for this city → the last saved of any city',
      () async {
        final prefs = await _prefs();
        await OpenMeteoWeatherRepository(_client(), prefs).report(_tashkent);
        final c = await OpenMeteoWeatherRepository(
          _client(down: true),
          prefs,
        ).report(_samarkand);
        expect(c.fromCache, isTrue);
        expect(c.place.id, 'tashkent');
      },
    );

    test('offline and nothing cached → throws', () async {
      final prefs = await _prefs();
      expect(
        OpenMeteoWeatherRepository(
          _client(down: true),
          prefs,
        ).report(_tashkent),
        throwsA(isA<SocketException>()),
      );
    });

    test('air quality down → forecast still shown, air empty', () async {
      final prefs = await _prefs();
      final r = await OpenMeteoWeatherRepository(
        _client(airDown: true),
        prefs,
      ).report(_tashkent);
      expect(r.air, isNull);
      expect(r.current.temp, 11.4);
    });

    test('request asks for the right place and fields', () {
      final u = OpenMeteoWeatherRepository.forecastUri(_samarkand);
      expect(u.host, 'api.open-meteo.com');
      expect(u.queryParameters['latitude'], '39.6542');
      expect(u.queryParameters['timezone'], 'auto');
      expect(
        OpenMeteoWeatherRepository.airUri(_samarkand)
            .queryParameters['current'],
        contains('us_aqi'),
      );
    });
  });

  group('providers', () {
    ProviderContainer container(
      SharedPreferences prefs, {
      required WeatherLocator locator,
      http.Client? client,
    }) => ProviderContainer(
      overrides: [
        useFakeProvider.overrideWithValue(false),
        sharedPreferencesProvider.overrideWithValue(prefs),
        weatherHttpClientProvider.overrideWithValue(client ?? _client()),
        weatherLocatorProvider.overrideWithValue(locator),
      ],
    );

    test('city: report + today’s AQI saved for workouts', () async {
      final prefs = await _prefs({'weather.place': 'samarkand'});
      final c = container(prefs, locator: _Locator(null));
      addTearDown(c.dispose);
      final r = await c.read(weatherReportProvider.future);
      expect(r.place.id, 'samarkand');
      final saved = jsonDecode(prefs.getString(todayAqiKey)!) as Map;
      expect(saved['aqi'], 135);
      expect((saved['place'] as Map)['uz'], 'Samarqand');
    });

    test('my location: named after the nearest city', () async {
      final prefs = await _prefs({'weather.place': gpsPlaceId});
      final c = container(prefs, locator: _Locator((lat: 39.66, lng: 66.95)));
      addTearDown(c.dispose);
      final r = await c.read(weatherReportProvider.future);
      expect(r.place.isGps, isTrue);
      expect(r.place.name['uz'], 'Samarqand');
      expect(r.place.lat, 39.66);
    });

    test('my location unavailable: cached gps report, else an error', () async {
      final prefs = await _prefs({'weather.place': gpsPlaceId});
      final c = container(prefs, locator: _Locator(null));
      addTearDown(c.dispose);
      await expectLater(
        c.read(weatherReportProvider.future),
        throwsA(isA<LocationUnavailableException>()),
      );

      final c2 = container(prefs, locator: _Locator((lat: 41.3, lng: 69.3)));
      await c2.read(weatherReportProvider.future); // caches «gps»
      c2.dispose();

      final c3 = container(prefs, locator: _Locator(null));
      addTearDown(c3.dispose);
      final r = await c3.read(weatherReportProvider.future);
      expect(r.fromCache, isTrue);
      expect(r.place.isGps, isTrue);
    });

    test(
      'selected place persists; unknown id falls back to Tashkent',
      () async {
        final prefs = await _prefs({'weather.place': 'atlantis'});
        final c = container(prefs, locator: _Locator(null));
        addTearDown(c.dispose);
        expect(c.read(weatherPlaceProvider), 'tashkent');
        await c.read(weatherPlaceProvider.notifier).select('bukhara');
        expect(prefs.getString(WeatherPlaceNotifier.key), 'bukhara');
      },
    );
  });

  test('fake demo: Tashkent AQI > 100, Samarkand clean', () async {
    final prefs = await _prefs();
    final repo = FakeWeatherRepository(prefs);
    final t = await repo.report(_tashkent);
    final s = await repo.report(_samarkand);
    expect(t.air!.aqi, greaterThan(100));
    expect(s.air!.aqi, lessThanOrEqualTo(100));
    expect(t.hours, hasLength(24));
    expect(t.days, hasLength(7));
    expect(t.hours.first.time.hour, DateTime.now().hour);
    expect(repo.cached('samarkand'), isNotNull);
  });
}

class _Locator implements WeatherLocator {
  _Locator(this.at);

  final ({double lat, double lng})? at;

  @override
  Future<({double lat, double lng})?> current() async => at;
}
