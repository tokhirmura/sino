# Фича `workouts`

**Владелец:** модуль C

## Что делает
Генерация плана тренировок по параметрам, выполнение тренировки (таймер, повторы), история и сожжённые калории.

Каталог и seed — см. `lib/features/nutrition/CLAUDE.md`. `plan` jsonb — список `PlanDay`
(`day`, `weekday` 1=Пн…7=Вс, `items[{exercise_id, sets, reps|seconds}]`, `minutes`, `kcal`).

## Маршруты
- `/workouts` (`AppRoutes.workouts`) — вкладка «Sport»
- `/workouts/play/:day` (`workoutPlayerPath(day)`, `day` = `PlanDay.day`) — плеер на весь экран (`rootNavigatorKey`)

## Home-карточки
- `workouts`, order 60 — `WorkoutsHomeCard`: следующая тренировка («Bugun · Dushanba» / «Ertaga · …» / день
  недели, минуты, ~ккал, число упражнений, иконка вида) и серия 🔥, на сегодня — кнопка ▶ (плеер); без плана — приглашение составить план

## Таблицы БД
`exercises`, `workout_plans`, `workout_sessions`

## Файлы
- `workouts_feature.dart` — единственный публичный файл (`workoutsRoutes`, `workoutsHomeCards`)
- `data/models.dart` — `WorkoutType`, `Exercise` (`kcalPerMin`), `PlanItem`, `PlanDay`, `WorkoutPlan`, `WorkoutSession`
- `data/workouts_repository.dart` — `WorkoutsRepository` (каталог, план, сессии) + Supabase + Fake
- `application/workout_math.dart` — время и ~ккал упражнения (повтор ≈ 3 с), оценка дня (отдых между подходами —
  время + ~2 ккал/мин), серия дней, `nextWorkout` (сегодня, если сессии сегодня ещё нет, иначе следующий день плана)
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
  `sessionsProvider`, `streakProvider`, `planActionsProvider` (`create(params)`: генерация → `workout_plans`),
  `nextWorkoutProvider`, `sessionActionsProvider` (`save(planDay, kcal)` → `workout_sessions`, обновляет серию)
- `application/air_quality.dart` — `readTodayAqi` (prefs `weather.today_aqi` от фичи weather, свежее 6 ч),
  `TodayAqi.isBad` (AQI > 100), `isOutdoor` (бег), `adjustForAir(params, aqi)` (S2-1, чистая функция: AQI > 100 и бег / параметры по умолчанию → «uyda»,
  `homeForAir`; зал, йога, плавание, кураш не трогает). Форма генератора: плохой воздух и бег/план по умолчанию → «uyda»
  с баннером `airAlertText` «Havo ifloslangan (AQI 135, Toshkent) — bugun uyda mashq qiling» (тот же текст, что у weather); выбрал бег — предупреждение и кнопка «Uyda». План бега в такой
  день — карточка-предупреждение «Uyda reja»
- `application/workout_run.dart` — плеер без Flutter: `buildSteps` (подходы + отдых `params.rest_seconds` между ними,
  после последнего нет), `WorkoutRun` (ready 5 с → work → rest → … → done; `tick` раз в секунду, `completeSet`,
  `skip` (готовность/отдых), `skipSet`, `addRest` +15 с, `togglePause`, `finish`). ~ккал = фактическая работа
  (подход повторов = повторы × 3 с, таймер — отработанные секунды) + отдых 2 ккал/мин; XP = ккал + 5 за подход +
  20 за все подходы (не хранится — считается из сессии)
- `presentation/workout_player_screen.dart` — плеер: кольцо-таймер, «× 12 marta» + «Bajarildi», отдых с «+15 s» и
  «O‘tkazib yuborish», пауза, «Keyingi», выход с диалогом (продолжить / завершить и сохранить / выйти без сохранения),
  финал: минуты, ~ккал, XP, «Ketma-ket N kun!» после сохранения (ошибка — «Qayta urinish»)
- Плеер 2.0 (S2-4):
  - `application/voice_coach.dart` — без Flutter: `VoiceLang` uz/ru/en, `VoiceChoice` auto/uz/ru/en/off, `resolveVoice`
    (auto = язык приложения; нет голоса → uz→ru→en, ru↔en; нет ничего → молчит), `numberWord` 1…99 (uz «bir, o'n bir»,
    ru «раз… двадцать один», en «forty-two»), `startCue`, `cues(before, after, lang)`: готовность/отдых/таймер —
    «uch, ikki, bir» в конце, таймер ≥ 20 с — «Yarmi o'tdi», вход в подход — «Planka. 20 soniya. Boshladik!» /
    «12 marta», отдых — «Dam oling. Keyingisi: …», повторы — счёт темпом 3 с/повтор, потом «Ofarin! «Bajarildi»ni
    bosing», финал — «Mashg'ulot tugadi! Barakalla!»; на паузе — тишина
  - `data/voice.dart` — `Speaker` (`available`, `say`, `stop`): `FlutterTtsSpeaker` (isLanguageAvailable / getLanguages;
    iOS — playback + duckOthers/mixWithOthers поверх музыки; ошибки TTS глотает), `FakeSpeaker` для тестов
  - `application/voice_providers.dart` — `voiceChoiceProvider` (prefs `workouts.voice`), `voiceLangsProvider`,
    `activeVoiceProvider`
  - экран: кнопка 🔊 `player-voice` → лист «Ovozli murabbiy» (Avtomatik «Hozir: Русский», языки без голоса —
    «Telefonda bu ovoz yo‘q», O‘chirilgan); финал — `confetti` в цветах бренда (4 с, потом уходит из дерева; при
    «уменьшить движение» — нет), XP считает вверх на шафрановой карточке
- `presentation/workouts_screen.dart` — дизайн 2.0: `GradientHeader` (с планом — `StatTile` серия / минут в неделю /
  ~ккал, появление `flutter_animate`), `SkeletonLoader`, нет плана — `EmptyState` + форма (`PrimaryButton`
  «Reja tuzish»); нет плана: форма генератора; есть — сводка недели и дни, «Yangi reja tuzish»
  (bottom sheet); `labels.dart` — названия видов/целей/уровней/дней недели, дозировка; `widgets/plan_form.dart`,
  `widgets/plan_day_card.dart`, `widgets/workouts_home_card.dart`
- Тесты: `test/features/workouts/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] P0-1 Данные: `assets/wellness/exercises.json` (40 упражнений, type `home|gym|run|yoga|swim|kurash`),
  колонка `exercises.kcal_per_min`, seed-миграция, модели, репозиторий (каталог + `workout_plans` +
  `workout_sessions`), провайдеры, юнит-тесты расчётов на Fake
- [x] P0-3 Генератор плана: вид (uyda, zal, yugurish, yoga, suzish, kurash O‘FP) × цель (ozish, massa,
  chidamlilik, egiluvchanlik) × уровень × дней в неделю (2–6) → недельный план с минутами и ~ккал;
  детерминированные правила, сохранение в `workout_plans`
- [x] P0-4 `workoutsHomeCards`: следующая тренировка
- [x] P1-5 Плеер тренировки на весь экран: подходы/повторы, таймер, отдых с отсчётом (можно пропустить),
  финал с ~ккал и XP → `workout_sessions`; серия дней по сессиям
- [x] P1-6 Генератор учитывает AQI (при AQI > 100 советует «uyda»)

## Sprint 2.0
Номер задачи — из плана спринта (S2-1 … S2-7). Одна задача = один PR. Проверка экранов: телефон Android (USB),
эмулятор Android, симулятор iOS — в обоих режимах (`env.json` и `USE_FAKE=true`).
- [x] S2-1 Воздух: AQI > 100 → состояние-предупреждение «Havo ifloslangan (AQI 156) — bugun uyda mashq qiling»
  (uz/ru/en), выбор «uyda» генератором — чистая функция `adjustForAir`, тесты
- [x] S2-2 Дизайн 2.0: `GradientHeader`, `StatTile`, `SkeletonLoader`, `EmptyState`, `PrimaryButton`, `flutter_animate`
- [x] S2-4 Плеер 2.0: голосовой счёт `flutter_tts` («Bir, ikki, uch…», «Dam oling»); нет узбекского голоса — русский,
  выбор в настройках; в конце — confetti и XP
