import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/prefs.dart';
import '../data/models.dart';
import '../data/weather_repository.dart';

/// Selected place: a city id or `gps`. Tashkent by default (no location
/// prompt until the user picks «my location»).
class WeatherPlaceNotifier extends Notifier<String> {
  static const key = 'weather.place';

  @override
  String build() {
    final id = ref.watch(sharedPreferencesProvider).getString(key);
    return id == gpsPlaceId || cityById(id) != null
        ? id!
        : weatherCities.first.id;
  }

  Future<void> select(String id) async {
    if (id == state) return;
    state = id;
    await ref.read(sharedPreferencesProvider).setString(key, id);
  }
}

final weatherPlaceProvider = NotifierProvider<WeatherPlaceNotifier, String>(
  WeatherPlaceNotifier.new,
);

/// Location could not be found (off / denied / no fix) and nothing cached.
class LocationUnavailableException implements Exception {
  const LocationUnavailableException();
}

/// Today's AQI for other features (workouts, P1-6) without importing this
/// one: written to prefs on every report as
/// `{"aqi": 135, "at": "<UTC ISO>", "place": {uz, ru, en}}`.
/// Readers should ignore values older than a few hours.
const todayAqiKey = 'weather.today_aqi';

/// Report of the selected place (network → cache → error). No automatic
/// retry: it would ask for location permission again and again; the screen
/// has «Retry» and pull-to-refresh.
final weatherReportProvider = FutureProvider<WeatherReport>(retry: _noRetry, (
  ref,
) async {
  final id = ref.watch(weatherPlaceProvider);
  final repo = ref.watch(weatherRepositoryProvider);
  final WeatherReport report;
  if (id == gpsPlaceId) {
    final at = await ref.watch(weatherLocatorProvider).current();
    if (at == null) {
      final cached = repo.cached(gpsPlaceId);
      if (cached == null) throw const LocationUnavailableException();
      report = cached.copyWith(fromCache: true);
    } else {
      final near = nearestCity(at.lat, at.lng);
      report = await repo.report(
        WeatherPlace(id: gpsPlaceId, name: near.name, lat: at.lat, lng: at.lng),
      );
    }
  } else {
    report = await repo.report(cityById(id)!);
  }
  final air = report.air;
  if (air != null) {
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          todayAqiKey,
          jsonEncode({
            'aqi': air.aqi,
            'at': report.fetchedAt.toUtc().toIso8601String(),
            'place': report.place.name,
          }),
        );
  }
  return report;
});

Duration? _noRetry(int retryCount, Object error) => null;
