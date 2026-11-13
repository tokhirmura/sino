# Фича `nutrition`

**Владелец:** модуль C

## Что делает
Дневник питания (завтрак/обед/ужин/перекус), калории и БЖУ (`fl_chart`, `ProgressRing`), трекер воды.

Каталоги `foods` / `exercises`: источник — `assets/wellness/foods.json` и `exercises.json` (формат таблицы;
`id` — фиксированные uuid `f0000000-…` / `e0000000-…`, общие для assets, Fake и Supabase; `slug` — только в
assets, в БД не пишется). После правки JSON: `dart run tool/wellness/gen_seed.dart` → перегенерирует
`supabase/migrations/20261114120100_wellness_seed.sql` (тест сверяет файл с assets). Колонка
`exercises.kcal_per_min` — миграция `20261114120000_wellness_exercise_kcal.sql`. Миграции пушит лид.
Fake-режим: пользовательские данные в prefs (`nutrition.fake_*`, `workouts.fake_*`, `vitals.fake_list`),
при первом чтении — демо из `assets/wellness/fake_wellness.json` (даты относительно сегодня).

## Маршруты
- `/nutrition` (`AppRoutes.nutrition`) — вкладка «Ovqat»

## Home-карточки
- `nutrition`, order 50

## Таблицы БД
`foods`, `food_logs`, `water_logs`

## Файлы
- `nutrition_feature.dart` — единственный публичный файл (`nutritionRoutes`, `nutritionHomeCards`)
- `data/models.dart` — `Food`, `Meal`, `FoodLog` (join `foods(*)`), `WaterLog` (цель 8 стаканов)
- `data/nutrition_repository.dart` — `NutritionRepository` (каталог, дневник, вода) + Supabase + Fake, `searchFoods`
- `application/nutrition_math.dart` — суммы КБЖУ, non birligi (углеводы / 12), Миффлин–Сан Жеор (пола в профиле
  нет → средняя константа −78), цели БЖУ 20/30/50 %, шаг порции 0.5
- `application/nutrition_math.dart` (ещё) — подсказка по воде `waterHint` (темп 8 стаканов за 08:00–22:00,
  отставание на 1 стакан — ещё «в темпе»)
- `application/nutrition_providers.dart` — `foodsCatalogProvider`, `selectedDayProvider` (не в будущее),
  `dayLogsProvider(day)` (`DayLogsNotifier`: оптимистичные add / setServings / remove, откат и rethrow при ошибке;
  несохранённые записи — id `pending-…`), `waterProvider(day)` (`WaterNotifier`, 0…20), `kcalGoalFromProfileProvider`,
  `manualKcalGoalProvider` (prefs `nutrition.kcal_goal`, 800–6000, `null` = из профиля), `kcalGoalProvider`
- `presentation/nutrition_screen.dart` — экран дня; `labels.dart` — названия приёмов пищи, даты, единицы;
  `widgets/` — `DaySwitcher`, `CalorieSummaryCard` (кольцо, БЖУ, non birligi, диалог цели), `WaterCard`,
  `MealSection` (порции ±0.5, свайп/корзина — удалить, «Qaytarish»), `add_food_sheet.dart` (поиск, приём, порция)
- `tool/wellness/gen_seed.dart` + `seed_sql.dart` — генератор seed-миграции каталогов
- Тесты: `test/features/nutrition/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] P0-1 Данные: `assets/wellness/foods.json` (40 блюд), seed-миграция, модели `fromJson/toJson`, репозиторий
  (каталог + `food_logs` + `water_logs`), провайдеры, юнит-тесты расчётов на Fake
- [x] P0-2 `/nutrition`: дневник дня по приёмам пищи (Nonushta, Tushlik, Kechki ovqat, Gazak), переключение даты
- [x] P0-2 Добавление/удаление еды из поиска, порции шагом 0.5, оптимистичное обновление UI
- [x] P0-2 Кольцо калорий к цели (Миффлин–Сан Жеор из профиля, цель можно поменять вручную), полоски БЖУ,
  «non birligi» (углеводы / 12)
- [x] P0-2 Вода — 8 стаканов в `water_logs`; простая подсказка по балансу дня
- [ ] P0-4 `nutritionHomeCards`: калории и вода сегодня
- [ ] P2-8 «Taomni rasmdan aniqlash»: `image_picker` + мок-распознавание (анимация, 3 варианта, «beta»),
  фото в Supabase Storage (bucket и политики — попросить лида миграцией core)
