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
- `application/workout_math.dart` — время и ~ккал упражнения (повтор ≈ 3 с), оценка дня (отдых между подходами —
  время + ~2 ккал/мин), серия дней
- `application/plan_generator.dart` — `PlanParams` (type × `WorkoutGoal` lose|gain|endurance|flexibility ×
  `WorkoutLevel` × 2–6 дней; `toJson` → `workout_plans.params`), `generatePlan` — детерминированные правила:
  - дни недели: 2 → Пн/Чт, 3 → Пн/Ср/Пт, 4 → Пн/Вт/Чт/Пт, 5 → Пн–Ср/Пт/Сб, 6 → Пн–Сб
  - фокус дня: ≤3 дней и гибкость — всё тело; 4 — верх/низ; 5–6 — zal+massa push/pull/legs,
    иначе верх/низ/всё тело (massa) или верх/низ/кондиция
  - цель: ozish — круг из 6 упражнений, кардио вперёд, повторы ×1.4, отдых 30 с; massa — 5 силовых, 4 подхода,
    повторы ×0.7 (5–12), отдых 90 с, без кардио; chidamlilik — длительные, ×1.6, отдых 45 с;
    egiluvchanlik — йога/лёгкие упражнения, удержания ×1.6, отдых 20 с
  - уровень: подходы −1/0/+1, объём ×0.8/1/1.25; 2 дня — день длиннее (+1 упр., ×1.15), 5–6 — короче
  - длинные отрезки (бег, плавание, гребля ≥ 5 мин) — 1 подход, лимит минут в день по цели и уровню;
    день не длиннее 45/60/80 мин (по уровню) — иначе меньше упражнений
  - каждый день есть упражнение выбранного вида; massa для бега/плавания/йоги добавляет силовые «uyda»,
    egiluvchanlik для любого вида — растяжки йоги
- `application/workouts_providers.dart` — `exercisesProvider`, `exercisesByIdProvider`, `latestPlanProvider`,
  `sessionsProvider`, `streakProvider`, `planActionsProvider` (`create(params)`: генерация → `workout_plans`)
- `presentation/workouts_screen.dart` — нет плана: форма генератора; есть — сводка недели и дни, «Yangi reja tuzish»
  (bottom sheet); `labels.dart` — названия видов/целей/уровней/дней недели, дозировка; `widgets/plan_form.dart`,
  `widgets/plan_day_card.dart`
- Тесты: `test/features/workouts/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] P0-1 Данные: `assets/wellness/exercises.json` (40 упражнений, type `home|gym|run|yoga|swim|kurash`),
  колонка `exercises.kcal_per_min`, seed-миграция, модели, репозиторий (каталог + `workout_plans` +
  `workout_sessions`), провайдеры, юнит-тесты расчётов на Fake
- [x] P0-3 Генератор плана: вид (uyda, zal, yugurish, yoga, suzish, kurash O‘FP) × цель (ozish, massa,
  chidamlilik, egiluvchanlik) × уровень × дней в неделю (2–6) → недельный план с минутами и ~ккал;
  детерминированные правила, сохранение в `workout_plans`
- [ ] P0-4 `workoutsHomeCards`: следующая тренировка
- [ ] P1-5 Плеер тренировки на весь экран: подходы/повторы, таймер, отдых с отсчётом (можно пропустить),
  финал с ~ккал и XP → `workout_sessions`; серия дней по сессиям
- [ ] P1-6 Генератор учитывает AQI (при AQI > 100 советует «uyda»)
