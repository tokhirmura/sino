import '../data/models.dart';

/// US AQI category.
enum AqiLevel {
  good, // 0–50
  moderate, // 51–100
  sensitive, // 101–150: unhealthy for sensitive groups
  unhealthy, // 151–200
  veryUnhealthy, // 201–300
  hazardous; // 301+

  static AqiLevel of(int aqi) => aqi <= 50
      ? good
      : aqi <= 100
      ? moderate
      : aqi <= 150
      ? sensitive
      : aqi <= 200
      ? unhealthy
      : aqi <= 300
      ? veryUnhealthy
      : hazardous;
}

/// Above this AQI outdoor training is not advised (P1-6).
const outdoorAqiLimit = 100;

/// Kind of a piece of advice (the screen maps it to text and an icon).
enum WeatherTip {
  /// AQI > 150: stay inside, close windows, N95 outside.
  airBad,

  /// AQI 101–150: train at home; sensitive people stay inside.
  airSensitive,

  /// Rain is likely in the next hours.
  rain,

  /// ≥ 32 °C: heat — water, shade, train in the morning or evening.
  heat,

  /// ≤ 0 °C: cold — warm layers, warm up longer.
  cold,

  /// UV index ≥ 6 today.
  uv,

  /// Wind ≥ 35 km/h.
  wind,

  /// Nothing bad: a good day for a walk or an outdoor workout.
  goodDay,
}

/// Advice for a walk / outdoor workout, most important first.
List<WeatherTip> weatherTips(WeatherReport r) {
  final tips = <WeatherTip>[];
  final aqi = r.air?.aqi;
  if (aqi != null && aqi > 150) {
    tips.add(WeatherTip.airBad);
  } else if (aqi != null && aqi > outdoorAqiLimit) {
    tips.add(WeatherTip.airSensitive);
  }
  final soon = r.hours.take(6);
  if (soon.any((h) => h.precipChance >= 50 || _isWet(h.code))) {
    tips.add(WeatherTip.rain);
  }
  final t = r.current.feelsLike;
  if (t >= 32) tips.add(WeatherTip.heat);
  if (t <= 0) tips.add(WeatherTip.cold);
  if (r.days.isNotEmpty && r.days.first.uv >= 6) tips.add(WeatherTip.uv);
  if (r.current.wind >= 35) tips.add(WeatherTip.wind);
  if (tips.isEmpty) tips.add(WeatherTip.goodDay);
  return tips;
}

/// Is it a good time to train outside?
bool outdoorOk(WeatherReport r) {
  final tips = weatherTips(r);
  return !tips.any(
    (t) =>
        t == WeatherTip.airBad ||
        t == WeatherTip.airSensitive ||
        t == WeatherTip.rain,
  );
}

bool _isWet(int code) =>
    (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95;

/// Group of a WMO weather code (for an emoji and a word).
enum Sky { clear, partly, cloudy, fog, drizzle, rain, snow, showers, storm }

Sky skyOf(int code) => switch (code) {
  0 => Sky.clear,
  1 || 2 => Sky.partly,
  3 => Sky.cloudy,
  45 || 48 => Sky.fog,
  >= 51 && <= 57 => Sky.drizzle,
  >= 61 && <= 67 => Sky.rain,
  >= 71 && <= 77 || 85 || 86 => Sky.snow,
  >= 80 && <= 82 => Sky.showers,
  >= 95 => Sky.storm,
  _ => Sky.cloudy,
};

String skyEmoji(int code, {bool isDay = true}) => switch (skyOf(code)) {
  Sky.clear => isDay ? '☀️' : '🌙',
  Sky.partly => isDay ? '⛅' : '☁️',
  Sky.cloudy => '☁️',
  Sky.fog => '🌫️',
  Sky.drizzle => '🌦️',
  Sky.rain => '🌧️',
  Sky.snow => '❄️',
  Sky.showers => '🌦️',
  Sky.storm => '⛈️',
};
