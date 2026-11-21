/// Models of the weather feature. Data comes from Open-Meteo (forecast +
/// air quality); hand-written `fromJson` / `toJson` (also the offline cache).
library;

import 'dart:math' as math;

/// A place to show the weather for: a city of Uzbekistan or «my location».
class WeatherPlace {
  const WeatherPlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  /// `gps` for the current location, else a city id (`tashkent`).
  final String id;

  /// `{uz, ru, en}`; for `gps` — the nearest city.
  final Map<String, dynamic> name;
  final double lat;
  final double lng;

  bool get isGps => id == gpsPlaceId;

  factory WeatherPlace.fromJson(Map<String, dynamic> m) => WeatherPlace(
    id: m['id'] as String,
    name: Map<String, dynamic>.from(m['name'] as Map? ?? const {}),
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat': lat,
    'lng': lng,
  };
}

const gpsPlaceId = 'gps';

/// Regional centres of Uzbekistan; the first one is the default.
const weatherCities = <WeatherPlace>[
  WeatherPlace(
    id: 'tashkent',
    name: {'uz': 'Toshkent', 'ru': 'Ташкент', 'en': 'Tashkent'},
    lat: 41.2995,
    lng: 69.2401,
  ),
  WeatherPlace(
    id: 'samarkand',
    name: {'uz': 'Samarqand', 'ru': 'Самарканд', 'en': 'Samarkand'},
    lat: 39.6542,
    lng: 66.9597,
  ),
  WeatherPlace(
    id: 'bukhara',
    name: {'uz': 'Buxoro', 'ru': 'Бухара', 'en': 'Bukhara'},
    lat: 39.7681,
    lng: 64.4556,
  ),
  WeatherPlace(
    id: 'andijan',
    name: {'uz': 'Andijon', 'ru': 'Андижан', 'en': 'Andijan'},
    lat: 40.7821,
    lng: 72.3442,
  ),
  WeatherPlace(
    id: 'namangan',
    name: {'uz': 'Namangan', 'ru': 'Наманган', 'en': 'Namangan'},
    lat: 40.9983,
    lng: 71.6726,
  ),
  WeatherPlace(
    id: 'fergana',
    name: {'uz': 'Farg‘ona', 'ru': 'Фергана', 'en': 'Fergana'},
    lat: 40.3842,
    lng: 71.7843,
  ),
  WeatherPlace(
    id: 'nukus',
    name: {'uz': 'Nukus', 'ru': 'Нукус', 'en': 'Nukus'},
    lat: 42.4531,
    lng: 59.6103,
  ),
  WeatherPlace(
    id: 'urgench',
    name: {'uz': 'Urganch', 'ru': 'Ургенч', 'en': 'Urgench'},
    lat: 41.5500,
    lng: 60.6333,
  ),
  WeatherPlace(
    id: 'karshi',
    name: {'uz': 'Qarshi', 'ru': 'Карши', 'en': 'Karshi'},
    lat: 38.8606,
    lng: 65.7891,
  ),
  WeatherPlace(
    id: 'termez',
    name: {'uz': 'Termiz', 'ru': 'Термез', 'en': 'Termez'},
    lat: 37.2242,
    lng: 67.2783,
  ),
  WeatherPlace(
    id: 'navoi',
    name: {'uz': 'Navoiy', 'ru': 'Навои', 'en': 'Navoi'},
    lat: 40.0844,
    lng: 65.3792,
  ),
  WeatherPlace(
    id: 'jizzakh',
    name: {'uz': 'Jizzax', 'ru': 'Джизак', 'en': 'Jizzakh'},
    lat: 40.1158,
    lng: 67.8422,
  ),
  WeatherPlace(
    id: 'gulistan',
    name: {'uz': 'Guliston', 'ru': 'Гулистан', 'en': 'Gulistan'},
    lat: 40.4897,
    lng: 68.7842,
  ),
];

WeatherPlace? cityById(String? id) {
  for (final c in weatherCities) {
    if (c.id == id) return c;
  }
  return null;
}

/// Distance in km (haversine).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// The nearest city to a point (for naming «my location»).
WeatherPlace nearestCity(double lat, double lng) {
  var best = weatherCities.first;
  var bestKm = double.infinity;
  for (final c in weatherCities) {
    final km = distanceKm(lat, lng, c.lat, c.lng);
    if (km < bestKm) {
      best = c;
      bestKm = km;
    }
  }
  return best;
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.round() ?? 0;

/// Now: temperature °C, feels like, humidity %, wind km/h, WMO code.
class CurrentWeather {
  const CurrentWeather({
    required this.time,
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.wind,
    required this.code,
    this.isDay = true,
  });

  /// Local time of the place.
  final DateTime time;
  final double temp;
  final double feelsLike;
  final int humidity;
  final double wind;
  final int code;
  final bool isDay;

  factory CurrentWeather.fromJson(Map<String, dynamic> m) => CurrentWeather(
    time: DateTime.parse(m['time'] as String),
    temp: _d(m['temperature_2m']),
    feelsLike: _d(m['apparent_temperature']),
    humidity: _i(m['relative_humidity_2m']),
    wind: _d(m['wind_speed_10m']),
    code: _i(m['weather_code']),
    isDay: m['is_day'] == null ? true : _i(m['is_day']) == 1,
  );

  Map<String, dynamic> toJson() => {
    'time': _naive(time),
    'temperature_2m': temp,
    'apparent_temperature': feelsLike,
    'relative_humidity_2m': humidity,
    'wind_speed_10m': wind,
    'weather_code': code,
    'is_day': isDay ? 1 : 0,
  };
}

class HourWeather {
  const HourWeather({
    required this.time,
    required this.temp,
    required this.code,
    this.precipChance = 0,
  });

  final DateTime time;
  final double temp;
  final int code;
  final int precipChance;
}

class DayWeather {
  const DayWeather({
    required this.date,
    required this.code,
    required this.min,
    required this.max,
    this.precipChance = 0,
    this.uv = 0,
  });

  final DateTime date;
  final int code;
  final double min;
  final double max;
  final int precipChance;
  final double uv;
}

/// US AQI with PM2.5 / PM10 (μg/m³).
class AirQuality {
  const AirQuality({required this.aqi, this.pm25, this.pm10});

  final int aqi;
  final double? pm25;
  final double? pm10;

  factory AirQuality.fromJson(Map<String, dynamic> m) => AirQuality(
    aqi: _i(m['us_aqi']),
    pm25: (m['pm2_5'] as num?)?.toDouble(),
    pm10: (m['pm10'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {'us_aqi': aqi, 'pm2_5': pm25, 'pm10': pm10};
}

/// Forecast US AQI of one hour (local time of the place).
class AqiHour {
  const AqiHour(this.time, this.aqi);

  final DateTime time;
  final int aqi;
}

/// Local ISO time without zone, as Open-Meteo sends it.
String _naive(DateTime t) => t.toIso8601String().split('.').first;

String _date(DateTime t) => _naive(t).split('T').first;

/// Weather of a place: now, the next hours, 7 days, air quality.
class WeatherReport {
  const WeatherReport({
    required this.place,
    required this.fetchedAt,
    required this.current,
    required this.hours,
    required this.days,
    this.air,
    this.airHours = const [],
    this.fromCache = false,
  });

  final WeatherPlace place;

  /// When it was downloaded (device time).
  final DateTime fetchedAt;
  final CurrentWeather current;

  /// Next 24 hours from now (local time of the place).
  final List<HourWeather> hours;
  final List<DayWeather> days;

  /// `null` when the air quality service did not answer.
  final AirQuality? air;

  /// Hourly AQI forecast (today and tomorrow) for the morning alert
  /// (S2-7); empty when the service did not send it.
  final List<AqiHour> airHours;

  /// Shown from the offline cache (no network).
  final bool fromCache;

  WeatherReport copyWith({bool? fromCache, WeatherPlace? place}) =>
      WeatherReport(
        place: place ?? this.place,
        fetchedAt: fetchedAt,
        current: current,
        hours: hours,
        days: days,
        air: air,
        airHours: airHours,
        fromCache: fromCache ?? this.fromCache,
      );

  /// From the Open-Meteo answers (`forecast` and, optionally,
  /// `air-quality`). Hours start at the current hour of the place.
  factory WeatherReport.fromOpenMeteo({
    required WeatherPlace place,
    required Map<String, dynamic> forecast,
    Map<String, dynamic>? air,
    required DateTime fetchedAt,
  }) {
    final current = CurrentWeather.fromJson(
      Map<String, dynamic>.from(forecast['current'] as Map),
    );
    final h = Map<String, dynamic>.from(forecast['hourly'] as Map? ?? const {});
    final hTimes = (h['time'] as List? ?? const []).cast<String>();
    final from = DateTime(
      current.time.year,
      current.time.month,
      current.time.day,
      current.time.hour,
    );
    final hours = <HourWeather>[];
    for (var i = 0; i < hTimes.length && hours.length < 24; i++) {
      final t = DateTime.parse(hTimes[i]);
      if (t.isBefore(from)) continue;
      hours.add(
        HourWeather(
          time: t,
          temp: _d((h['temperature_2m'] as List)[i]),
          code: _i((h['weather_code'] as List)[i]),
          precipChance: _i((h['precipitation_probability'] as List?)?[i]),
        ),
      );
    }
    final dm = Map<String, dynamic>.from(forecast['daily'] as Map? ?? const {});
    final dTimes = (dm['time'] as List? ?? const []).cast<String>();
    final days = [
      for (var i = 0; i < dTimes.length; i++)
        DayWeather(
          date: DateTime.parse(dTimes[i]),
          code: _i((dm['weather_code'] as List)[i]),
          min: _d((dm['temperature_2m_min'] as List)[i]),
          max: _d((dm['temperature_2m_max'] as List)[i]),
          precipChance: _i((dm['precipitation_probability_max'] as List?)?[i]),
          uv: _d((dm['uv_index_max'] as List?)?[i]),
        ),
    ];
    final aqCurrent = air?['current'];
    final aqHourly = air?['hourly'];
    final airHours = <AqiHour>[];
    if (aqHourly is Map) {
      final times = aqHourly['time'] as List? ?? const [];
      final values = aqHourly['us_aqi'] as List? ?? const [];
      for (var i = 0; i < times.length && i < values.length; i++) {
        final v = values[i];
        if (v is! num) continue;
        airHours.add(AqiHour(DateTime.parse('${times[i]}'), v.round()));
      }
    }
    return WeatherReport(
      place: place,
      fetchedAt: fetchedAt,
      current: current,
      hours: hours,
      days: days,
      air: aqCurrent is Map && aqCurrent['us_aqi'] != null
          ? AirQuality.fromJson(Map<String, dynamic>.from(aqCurrent))
          : null,
      airHours: airHours,
    );
  }

  /// Cache format (same field names as Open-Meteo).
  Map<String, dynamic> toJson() => {
    'place': place.toJson(),
    'fetched_at': fetchedAt.toUtc().toIso8601String(),
    'current': current.toJson(),
    'hourly': {
      'time': [for (final x in hours) _naive(x.time)],
      'temperature_2m': [for (final x in hours) x.temp],
      'weather_code': [for (final x in hours) x.code],
      'precipitation_probability': [for (final x in hours) x.precipChance],
    },
    'daily': {
      'time': [for (final x in days) _date(x.date)],
      'weather_code': [for (final x in days) x.code],
      'temperature_2m_min': [for (final x in days) x.min],
      'temperature_2m_max': [for (final x in days) x.max],
      'precipitation_probability_max': [for (final x in days) x.precipChance],
      'uv_index_max': [for (final x in days) x.uv],
    },
    if (air != null) 'air': air!.toJson(),
    if (airHours.isNotEmpty)
      'air_hourly': {
        'time': [for (final x in airHours) _naive(x.time)],
        'us_aqi': [for (final x in airHours) x.aqi],
      },
  };

  factory WeatherReport.fromJson(Map<String, dynamic> m) {
    final r = WeatherReport.fromOpenMeteo(
      place: WeatherPlace.fromJson(
        Map<String, dynamic>.from(m['place'] as Map),
      ),
      forecast: m,
      air: {'current': m['air'], 'hourly': m['air_hourly']},
      fetchedAt: DateTime.parse(m['fetched_at'] as String).toLocal(),
    );
    return r;
  }
}
