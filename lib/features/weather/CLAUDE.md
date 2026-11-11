# Фича `weather`

**Владелец:** модуль C

## Что делает
Погода и качество воздуха (AQI) по геопозиции (`geolocator` + `http` к открытому API), советы по прогулке/тренировке на улице.

## Маршруты
- `/weather` (`AppRoutes.weather`) — полноэкранный

## Home-карточки
- `weather`, order 20

## Таблицы БД
— (внешний API, кэш в prefs с ключами `weather.*`)

## Файлы
- `weather_feature.dart` — единственный публичный файл (`weatherRoutes`, `weatherHomeCards`)
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- Тесты: `test/features/weather/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [ ]
