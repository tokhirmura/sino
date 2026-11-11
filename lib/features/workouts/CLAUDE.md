# Фича `workouts`

**Владелец:** модуль C

## Что делает
Генерация плана тренировок по параметрам, выполнение тренировки (таймер, повторы), история и сожжённые калории.

## Маршруты
- `/workouts` (`AppRoutes.workouts`) — вкладка «Sport»

## Home-карточки
- `workouts`, order 60

## Таблицы БД
`exercises`, `workout_plans`, `workout_sessions`

## Файлы
- `workouts_feature.dart` — единственный публичный файл (`workoutsRoutes`, `workoutsHomeCards`)
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- Тесты: `test/features/workouts/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [ ]
