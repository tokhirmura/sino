# Фича `weather`

**Владелец:** модуль C

## Что делает
Погода и качество воздуха (AQI) по геопозиции (`geolocator` + `http` к открытому API), советы по прогулке/тренировке на улице.

## Маршруты
- `/weather` (`AppRoutes.weather`) — полноэкранный

## Home-карточки
- `weather`, order 20 — `WeatherHomeCard`: «11° · Toshkent», небо, пилюля «AQI 135»; при AQI > 100 — «Bugun mashg‘ulotni
  uyda qiling»; тап → `/weather`

## Таблицы БД
— (внешний API Open-Meteo без ключа; кэш в prefs: `weather.cache.<placeId>`, `weather.cache.last`, выбор `weather.place`)

## Контракт с `workouts` (P1-6)
После каждого отчёта пишет prefs `weather.today_aqi` = `{"aqi": 135, "at": "<UTC ISO>", "place": {uz,ru,en}}`.
`workouts` читает его без импорта (`application/air_quality.dart`, свежесть ≤ 6 ч). Ключ и формат не менять без
правки `workouts`. Когда лид заведёт общий контракт в `lib/core/contracts`, перенести туда.

## Файлы
- `weather_feature.dart` — единственный публичный файл (`weatherRoutes`, `weatherHomeCards`)
- `data/models.dart` — `WeatherPlace` (13 областных центров + `gps`), `nearestCity`, `CurrentWeather`, `HourWeather`,
  `DayWeather`, `AirQuality` (US AQI, PM2.5, PM10), `WeatherReport` (`fromOpenMeteo`, `toJson/fromJson` — кэш;
  часы с текущего часа места, `fromCache`)
- `data/weather_repository.dart` — `WeatherRepository`: `OpenMeteoWeatherRepository` (forecast + air-quality параллельно,
  таймаут 10 с; без сети → кэш места → последний кэш любого места → ошибка; нет AQI — `air = null`),
  `FakeWeatherRepository` (`assets/wellness/fake_weather.json`: Toshkent AQI 135, Samarqand 58, Buxoro 44; время от
  «сейчас»), `WeatherCache`, `WeatherLocator` (Geolocator: low accuracy 8 с → last known; Fake — Toshkent)
- `application/weather_logic.dart` — `AqiLevel` (0–50 … 301+), `outdoorAqiLimit` = 100, `weatherTips` (воздух, дождь
  в ближайшие 6 ч, жара ≥ 32, холод ≤ 0 по «ощущается», УФ ≥ 6, ветер ≥ 35 км/ч, иначе «хороший день»), WMO → `Sky`
- `application/weather_providers.dart` — `weatherPlaceProvider` (по умолчанию Toshkent — без запроса геолокации),
  `weatherReportProvider` (без авто-retry: иначе повторный запрос разрешения; `gps` без координат → кэш `gps` или
  `LocationUnavailableException`), `todayAqiKey`
- `presentation/weather_screen.dart` — чипы «Joylashuvim» + города, баннер «Internet yo‘q — oxirgi saqlangan prognoz
  (N soat oldin)», сейчас (градиент), AQI с кнопкой «Uyda mashg‘ulot» при AQI > 100, советы, 24 часа, 7 дней,
  дисклеймер; `weather_home_card.dart`; `labels.dart`
- Тесты: `test/features/weather/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] P1-6 `/weather`: города (Toshkent, Samarqand, …) и геолокация, сейчас / 24 ч / 7 дней, AQI, советы для прогулки
  и тренировки, офлайн-кэш последнего прогноза
- [x] P1-6 Карточка главной (order 20): температура, город, AQI; при плохом воздухе — «дома»
- [x] P1-6 Сегодняшний AQI для генератора тренировок (`weather.today_aqi`)
