# Фича `nutrition`

**Владелец:** модуль C

## Что делает
Дневник питания (завтрак/обед/ужин/перекус), калории и БЖУ (`fl_chart`, `ProgressRing`), трекер воды.

## Маршруты
- `/nutrition` (`AppRoutes.nutrition`) — вкладка «Ovqat»

## Home-карточки
- `nutrition`, order 50

## Таблицы БД
`foods`, `food_logs`, `water_logs`

## Файлы
- `nutrition_feature.dart` — единственный публичный файл (`nutritionRoutes`, `nutritionHomeCards`)
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- Тесты: `test/features/nutrition/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [ ]
