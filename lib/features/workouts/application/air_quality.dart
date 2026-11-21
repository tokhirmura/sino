import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import 'plan_generator.dart';

/// Today's air quality as the weather feature saved it (P1-6).
///
/// Contract with `weather` (no import between features): prefs key
/// [todayAqiKey] = `{"aqi": 135, "at": "<UTC ISO>", "place": {uz, ru, en}}`,
/// written on every weather report.
class TodayAqi {
  const TodayAqi({required this.aqi, required this.at, this.place = const {}});

  final int aqi;
  final DateTime at;
  final Map<String, dynamic> place;

  /// Outdoor training is not advised above this (US AQI).
  bool get isBad => aqi > badAqiLimit;
}

const todayAqiKey = 'weather.today_aqi';
const badAqiLimit = 100;

/// Older values say nothing about today.
const todayAqiMaxAge = Duration(hours: 6);

/// The saved AQI if it is fresh, else `null`.
TodayAqi? readTodayAqi(SharedPreferences prefs, DateTime now) {
  final raw = prefs.getString(todayAqiKey);
  if (raw == null) return null;
  try {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final at = DateTime.parse(m['at'] as String).toLocal();
    if (now.difference(at) > todayAqiMaxAge ||
        at.isAfter(now.add(const Duration(minutes: 5)))) {
      return null;
    }
    return TodayAqi(
      aqi: (m['aqi'] as num).round(),
      at: at,
      place: Map<String, dynamic>.from(m['place'] as Map? ?? const {}),
    );
  } catch (_) {
    return null;
  }
}

/// Sports done outside (bad air matters).
bool isOutdoor(WorkoutType t) => t == WorkoutType.run;

/// Generator inputs adjusted for today's air (Sprint 2.0, S2-1).
///
/// With a bad AQI ([TodayAqi.isBad]) an outdoor sport or untouched defaults
/// become «at home», and [homeForAir] tells the form to say the generator
/// chose it. Indoor sports the user picked (gym, yoga, …) stay as they are.
/// Applied once to the form's starting values, so a later tap on «run» is
/// the user's own choice and is not overridden.
({PlanParams params, bool homeForAir}) adjustForAir(
  PlanParams params,
  TodayAqi? aqi,
) {
  final outdoorOrDefault =
      isOutdoor(params.type) || params == const PlanParams();
  if (aqi == null || !aqi.isBad || !outdoorOrDefault) {
    return (params: params, homeForAir: false);
  }
  return (params: params.copyWith(type: WorkoutType.home), homeForAir: true);
}
