import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/backend/backend.dart';
import '../../../core/storage/prefs.dart';
import 'models.dart';

/// Weather of a place. Every successful download is cached in prefs, so
/// without network the last saved forecast is shown (`fromCache`).
abstract class WeatherRepository {
  /// Fresh report; without network — the cached one of [place], else the
  /// last cached report of any place. Throws if there is nothing cached.
  Future<WeatherReport> report(WeatherPlace place);

  /// Cached report of a place (`gps` included), `null` if none.
  WeatherReport? cached(String placeId);
}

/// Prefs cache shared by the implementations.
class WeatherCache {
  WeatherCache(this._prefs);

  final SharedPreferences _prefs;

  static const prefix = 'weather.cache.';
  static const lastKey = 'weather.cache.last';

  WeatherReport? read(String placeId) {
    final raw = _prefs.getString('$prefix$placeId');
    if (raw == null) return null;
    try {
      return WeatherReport.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // an old / broken cache is just ignored
    }
  }

  WeatherReport? last() {
    final id = _prefs.getString(lastKey);
    return id == null ? null : read(id);
  }

  Future<void> write(WeatherReport r) async {
    await _prefs.setString('$prefix${r.place.id}', jsonEncode(r.toJson()));
    await _prefs.setString(lastKey, r.place.id);
  }
}

/// Open-Meteo: free, no key. Forecast and air quality are two requests;
/// a failed air quality request only leaves `air` empty.
class OpenMeteoWeatherRepository implements WeatherRepository {
  OpenMeteoWeatherRepository(this._client, SharedPreferences prefs)
    : _cache = WeatherCache(prefs);

  final http.Client _client;
  final WeatherCache _cache;

  static const timeout = Duration(seconds: 10);

  static Uri forecastUri(WeatherPlace p) =>
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': p.lat.toStringAsFixed(4),
        'longitude': p.lng.toStringAsFixed(4),
        'current':
            'temperature_2m,apparent_temperature,relative_humidity_2m,'
            'weather_code,wind_speed_10m,is_day',
        'hourly': 'temperature_2m,weather_code,precipitation_probability',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,'
            'precipitation_probability_max,uv_index_max',
        'timezone': 'auto',
        'forecast_days': '7',
      });

  static Uri airUri(WeatherPlace p) =>
      Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
        'latitude': p.lat.toStringAsFixed(4),
        'longitude': p.lng.toStringAsFixed(4),
        'current': 'us_aqi,pm2_5,pm10',
        'timezone': 'auto',
      });

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final res = await _client.get(uri).timeout(timeout);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}', uri);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  @override
  Future<WeatherReport> report(WeatherPlace place) async {
    final airFuture = _get(airUri(place))
        .then<Map<String, dynamic>?>((m) => m)
        .catchError((Object _) => null);
    final Map<String, dynamic> forecast;
    try {
      forecast = await _get(forecastUri(place));
    } catch (_) {
      await airFuture;
      final cached = _cache.read(place.id) ?? _cache.last();
      if (cached == null) rethrow;
      return cached.copyWith(fromCache: true);
    }
    final r = WeatherReport.fromOpenMeteo(
      place: place,
      forecast: forecast,
      air: await airFuture,
      fetchedAt: DateTime.now(),
    );
    await _cache.write(r);
    return r;
  }

  @override
  WeatherReport? cached(String placeId) => _cache.read(placeId);
}

/// Offline demo from `assets/wellness/fake_weather.json` (times relative
/// to now). Tashkent has AQI above 100 — the «train at home» case.
class FakeWeatherRepository implements WeatherRepository {
  FakeWeatherRepository(SharedPreferences prefs, {AssetBundle? bundle})
    : _cache = WeatherCache(prefs),
      _bundle = bundle ?? rootBundle;

  final WeatherCache _cache;
  final AssetBundle _bundle;

  static const asset = 'assets/wellness/fake_weather.json';

  @override
  Future<WeatherReport> report(WeatherPlace place) async {
    final all = jsonDecode(
      await _bundle.loadString(asset, cache: false),
    ) as Map<String, dynamic>;
    final key = place.isGps ? nearestCity(place.lat, place.lng).id : place.id;
    final demo = Map<String, dynamic>.from(
      (all[key] ?? all['tashkent']) as Map,
    );
    final r = fakeReport(place, demo, DateTime.now());
    await _cache.write(r);
    return r;
  }

  @override
  WeatherReport? cached(String placeId) => _cache.read(placeId);

  /// Builds a report from a demo entry: `current`, `air`, 24 hourly
  /// `temps` / `codes` / `precip` from the current hour, 7 `days`.
  static WeatherReport fakeReport(
    WeatherPlace place,
    Map<String, dynamic> demo,
    DateTime now,
  ) {
    final hour = DateTime(now.year, now.month, now.day, now.hour);
    final today = DateTime(now.year, now.month, now.day);
    String naive(DateTime t) => t.toIso8601String().split('.').first;
    final temps = (demo['temps'] as List).cast<num>();
    final codes = (demo['codes'] as List).cast<num>();
    final precip = (demo['precip'] as List).cast<num>();
    final days = (demo['days'] as List).cast<Map>();
    return WeatherReport.fromOpenMeteo(
      place: place,
      fetchedAt: now,
      forecast: {
        'current': {
          ...Map<String, dynamic>.from(demo['current'] as Map),
          'time': naive(now),
          'is_day': now.hour >= 7 && now.hour < 18 ? 1 : 0,
        },
        'hourly': {
          'time': [
            for (var i = 0; i < temps.length; i++)
              naive(hour.add(Duration(hours: i))),
          ],
          'temperature_2m': temps,
          'weather_code': codes,
          'precipitation_probability': precip,
        },
        'daily': {
          'time': [
            for (var i = 0; i < days.length; i++)
              naive(DateTime(today.year, today.month, today.day + i))
                  .split('T')
                  .first,
          ],
          'weather_code': [for (final d in days) d['code']],
          'temperature_2m_min': [for (final d in days) d['min']],
          'temperature_2m_max': [for (final d in days) d['max']],
          'precipitation_probability_max': [for (final d in days) d['precip']],
          'uv_index_max': [for (final d in days) d['uv']],
        },
      },
      air: {'current': demo['air']},
    );
  }
}

/// Where the user is: `null` when location is off, denied or too slow.
abstract class WeatherLocator {
  Future<({double lat, double lng})?> current();
}

class GeolocatorWeatherLocator implements WeatherLocator {
  static const timeout = Duration(seconds: 8);

  @override
  Future<({double lat, double lng})?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final last = await Geolocator.getLastKnownPosition();
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: timeout,
          ),
        );
        return (lat: p.latitude, lng: p.longitude);
      } catch (_) {
        // No fix in time (indoors, airplane mode): the last known is fine
        // for the weather.
        return last == null ? null : (lat: last.latitude, lng: last.longitude);
      }
    } catch (_) {
      return null;
    }
  }
}

/// Offline: Amir Temur square, Tashkent.
class FakeWeatherLocator implements WeatherLocator {
  @override
  Future<({double lat, double lng})?> current() async =>
      (lat: 41.31108, lng: 69.27976);
}

final weatherHttpClientProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});

final weatherRepositoryProvider = Provider<WeatherRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeWeatherRepository(ref.watch(sharedPreferencesProvider))
      : OpenMeteoWeatherRepository(
          ref.watch(weatherHttpClientProvider),
          ref.watch(sharedPreferencesProvider),
        ),
);

final weatherLocatorProvider = Provider<WeatherLocator>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeWeatherLocator()
      : GeolocatorWeatherLocator(),
);
