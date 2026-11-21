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

/// How often an open weather screen fetches a fresh report by itself.
const weatherAutoRefresh = Duration(minutes: 1);

/// Report of the selected place (network → cache → error). No automatic
/// retry on error: it would ask for location permission again and again;
/// the screen has «Retry» and pull-to-refresh.
///
/// [WeatherReportNotifier.refresh] fetches again keeping the shown report:
/// the screen calls it every [weatherAutoRefresh] (`silent`) and on
/// pull-to-refresh / the refresh button.
class WeatherReportNotifier extends AsyncNotifier<WeatherReport> {
  @override
  Future<WeatherReport> build() {
    final id = ref.watch(weatherPlaceProvider);
    ref.watch(weatherRepositoryProvider);
    ref.watch(weatherLocatorProvider);
    return _load(id, ask: true);
  }

  /// Fetches the report again without a loading state in between.
  ///
  /// [silent] (the minute timer): never asks for location permission and
  /// keeps the shown report on failure. Otherwise a failure is rethrown
  /// (the screen shows it) and, if nothing was shown yet, becomes the state.
  Future<void> refresh({bool silent = false}) async {
    final id = ref.read(weatherPlaceProvider);
    try {
      final r = await _load(id, ask: !silent);
      // The place may have changed while fetching: that build wins.
      if (!ref.mounted || ref.read(weatherPlaceProvider) != id) return;
      state = AsyncData(r);
    } catch (e, st) {
      if (!ref.mounted || ref.read(weatherPlaceProvider) != id) return;
      if (state.hasValue) {
        if (silent) return;
        rethrow;
      }
      state = AsyncError(e, st);
      if (!silent) rethrow;
    }
  }

  Future<WeatherReport> _load(String id, {required bool ask}) async {
    final repo = ref.read(weatherRepositoryProvider);
    final WeatherReport report;
    if (id == gpsPlaceId) {
      final at = await ref.read(weatherLocatorProvider).current(ask: ask);
      if (at == null) {
        final cached = repo.cached(gpsPlaceId);
        if (cached == null) throw const LocationUnavailableException();
        report = cached.copyWith(fromCache: true);
      } else {
        final near = nearestCity(at.lat, at.lng);
        report = await repo.report(
          WeatherPlace(
            id: gpsPlaceId,
            name: near.name,
            lat: at.lat,
            lng: at.lng,
          ),
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
  }
}

final weatherReportProvider =
    AsyncNotifierProvider<WeatherReportNotifier, WeatherReport>(
      WeatherReportNotifier.new,
      retry: _noRetry,
    );

Duration? _noRetry(int retryCount, Object error) => null;
