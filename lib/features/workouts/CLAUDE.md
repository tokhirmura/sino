# Фича `workouts`

**Владелец:** модуль C

## Что делает
Генерация плана тренировок по параметрам, выполнение тренировки (таймер, повторы), история и сожжённые калории.

Каталог и seed — см. `lib/features/nutrition/CLAUDE.md`. `plan` jsonb — список `PlanDay`
(`day`, `weekday` 1=Пн…7=Вс, `items[{exercise_id, sets, reps|seconds}]`, `minutes`, `kcal`).

## Маршруты
- `/workouts` (`AppRoutes.workouts`) — вкладка «Sport»

## Home-карточки
- `workouts`, order 60

## Таблицы БД
`exercises`, `workout_plans`, `workout_sessions`

## Файлы
- `workouts_feature.dart` — единственный публичный файл (`workoutsRoutes`, `workoutsHomeCards`)
- `data/models.dart` — `WorkoutType`, `Exercise` (`kcalPerMin`), `PlanItem`, `PlanDay`, `WorkoutPlan`, `WorkoutSession`
- `data/workouts_repository.dart` — `WorkoutsRepository` (каталог, план, сессии) + Supabase + Fake
- `application/workout_math.dart` — время и ~ккал упражнения (повтор ≈ 3 с), оценка дня, серия дней
- `application/workouts_providers.dart` — `exercisesProvider`, `exercisesByIdProvider`, `latestPlanProvider`,
  `sessionsProvider`, `streakProvider`
- Тесты: `test/features/workouts/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] P0-1 Данные: `assets/wellness/exercises.json` (40 упражнений, type `home|gym|run|yoga|swim|kurash`),
  колонка `exercises.kcal_per_min`, seed-миграция, модели, репозиторий (каталог + `workout_plans` +
  `workout_sessions`), провайдеры, юнит-тесты расчётов на Fake
- [ ] P0-3 Генератор плана: вид (uyda, zal, yugurish, yoga, suzish, kurash O‘FP) × цель (ozish, massa,
  chidamlilik, egiluvchanlik) × уровень × дней в неделю (2–6) → недельный план с минутами и ~ккал;
  детерминированные правила, сохранение в `workout_plans`
- [ ] P0-4 `workoutsHomeCards`: следующая тренировка
- [ ] P1-5 Плеер тренировки на весь экран: подходы/повторы, таймер, отдых с отсчётом (можно пропустить),
  финал с ~ккал и XP → `workout_sessions`; серия дней по сессиям
- [ ] P1-6 Генератор учитывает AQI (при AQI > 100 советует «uyda»)
