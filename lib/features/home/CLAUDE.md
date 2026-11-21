# Фича `home`

**Владелец:** модуль A (лид)

## Что делает
Главная «Bugun» сверху вниз (`presentation/home_screen.dart`, всё появляется каскадом):
- `HomeHeader` — `GradientHeader`: приветствие по времени суток (`DayPart`: 05–11 «Xayrli tong», 11–17 «Xayrli kun»,
  иначе «Xayrli kech») + имя, дата, **живая строка-итог** (`todaySummary`: «Bugun 1 240 kkal, 5 stakan suv,
  dorilar vaqtida ✓, 6 400 qadam» — только то, что отмечено; ничего — «suvdan boshlang 💧»).
- `SinoIndexCard` — большое анимированное кольцо индекса Sino, уровень (A’lo / Yaxshi / O‘rtacha / Yaxshilash
  mumkin), мини-полоски; тап → лист «Indeks qanday hisoblanadi»: каждая часть с баллами, значением и «Qo‘shish»
  для частей без данных. Нет данных за сегодня — пустое кольцо и «Qo‘shish».
- `WeekStripCard` — серия дней с индексом ≥ 60 (`sinoStreak` по 30 дням; сегодняшний день, пока < 60, серию не
  рвёт) и 7 цветных точек с индексом (≥ 80 зелёная, ≥ 60 бирюзовая, ≥ 40 шафран, ниже — терракота, нет данных — «–»).
  Тап по карточке или «Hisobot ›» → недельный отчёт `/report`.
- `QuoteCard` — «Kun hikmati»: 20 поговорок и изречений о здоровье в `assets/core/quotes.json` (uz + ru/en),
  одна на день (номер дня в году % 20); оригинал всегда на узбекском, в ru/en под ним перевод.
- «Xizmatlar» 3×3 и «Siz uchun» — карточки всех фич из `homeCardsProvider` (сортировка по `order`). Если у профиля
  есть цель (`profiles.goal`), под «Siz uchun» — плашка цели, а `orderCardsForGoal` (`application/goal_order.dart`)
  ставит SOS первой, затем карточки цели (`goalCardPriority` по id: похудеть — nutrition, workouts, vitals; энергия —
  workouts, breathing, nutrition, weather; давление/сахар — vitals, reminders, nutrition, doctors; семья — family,
  reminders, doctors, pharmacy), остальные — как были.

**Достижения** (`application/achievements_check.dart`): при каждой загрузке истории `earnedAchievements` проверяет
8 значков core `Achievement` по 30 дням — первая тренировка, 7 дней подряд по 8 стаканов, 3 дня подряд все дозы приняты,
первая бронь (`reservations`, свои строки), 10 000 шагов за день, индекс 90+ (минимум 3 части; сегодня — только после
21:00), 7 дней подряд индекс ≥ 60, «полный день» (все 5 частей). Новые сразу сохраняются (`achievementsRepositoryProvider`)
и празднуются диалогом «Yangi yutuq!» с confetti (`widgets/achievement_celebration.dart`, «Barcha yutuqlar» →
`AppRoutes.achievements`). Под `flutter test` диалог выключен (`achievementCelebrationProvider`) — confetti идёт по
настоящим часам, а диалог закрыл бы экраны в тестах коллег; тесты home включают его сами. Fake: у «Aziz» открываются
4 из 8.

**Недельный отчёт** `/report` (`presentation/report_screen.dart`, `application/weekly_report.dart`): последние 7 дней
(сегодня включительно) — средний индекс и разница с прошлой неделей («Birinchi hafta», если её нет), столбцы индекса
по дням на `fl_chart` (цвет уровня, пунктир 60), лучший день, вода (стаканы, дней с 8), тренировки (+ шаги в день),
лекарства вовремя (принято / наступившие дозы), дисклеймер. «Ulashish» — карточка снимается `screenshot` в PNG и
уходит в системный лист через `share_plus` с подписью (`reportSharerProvider`, в тестах подменяется). Нет данных за
неделю — `EmptyState`.

Обновление: при возврате на вкладку (слушает `GoRouter.routerDelegate`) и pull-to-refresh — `sinoHistoryProvider`
перечитывается, строка-итог и индекс сразу учитывают воду/еду/лекарства, отмеченные в других фичах.

**Индекс Sino 0–100** (`application/sino_index.dart`, за день, без диагноза): питание 25 (ккал к цели — Миффлин–Сан Жеор
из профиля ×1.375, как у nutrition; до 110 % цели — полный балл, 150 % — ноль), вода 20 (стаканы / 8), лекарства 20
(принято / наступившие дозы своих `reminders`, без членов семьи и на паузе, только с дня `created_at` напоминания), активность 20 (тренировка = полный балл,
иначе шаги `vitals.steps` / 8000), сон 15 (`vitals.sleep`, 7–9 ч = полный). Сегодня цели берутся пропорционально
прошедшей части дня (7:00 → 21:00, минимум 25 %). **Часть без данных не учитывается** — веса остальных растягиваются
до 100; совсем нет данных → `null`. Данные: `data/sino_data.dart` — `SinoDataRepository` читает таблицы напрямую
(только select своих строк, код коллег не импортируется); Fake — неделя «Aziz» из `assets/core/sino_week.json`
(один слабый день; «сегодня» растёт с часом дня и к ~17:30 даёт 1 240 ккал и 5 стаканов). Провайдеры:
`sinoHistoryProvider` (30 дней), `sinoWeekProvider` (7, сегодня последний), `sinoTodayProvider`,
`sinoStreakProvider`, `sinoClockProvider` (подменяется в тестах).

## Маршруты
- `/home` (`AppRoutes.home`) — вкладка «Asosiy»
- `/report` (`AppRoutes.report`) — недельный отчёт, полноэкранный (`homeFullscreenRoutes`)

## Home-карточки
— нет (показывает чужие карточки через `homeCardsProvider`)

## Таблицы БД
Только чтение своих строк: `food_logs` (+ `foods.kcal`), `water_logs`, `reminders`, `reminder_logs`,
`workout_sessions`, `vitals` (`steps`, `sleep`), `reservations` (есть ли хоть одна); `profiles` — через
`currentUserProvider`. Запись: `achievements` (через core-репозиторий, insert … on conflict do nothing).

## Файлы
- `home_feature.dart` — единственный публичный файл (`homeRoutes`, `homeFullscreenRoutes`, `homeHomeCards`)
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- Тесты: `test/features/home/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] P0-4 Приветствие по имени из `profiles`
- [x] P0-4 Карточка «индекс здоровья дня» (v1 — формула по данным профиля)
- [x] P0-4 Сетка быстрых сервисов на все маршруты `AppRoutes`
- [x] P0-4 Далее карточки `allHomeCards` (через `homeCardsProvider`); пустой список ничего не ломает
- [x] P1-6 Тёмная тема и uz/ru/en (проверяет `test/module_a_screens_test.dart`: 3 языка × 2 темы, 360×640)

## Спринт 2.0 (одна задача = один PR)
- [x] S2-1 Индекс Sino 0–100 (`application/sino_index.dart` + юнит-тесты): питание, вода, лекарства, активность, сон
  за сегодня; часть без данных не учитывается (веса перераспределяются); свой репозиторий читает таблицы Supabase
  (select своих строк), Fake — правдоподобная неделя «Aziz»
- [x] S2-2 Главная «Bugun»: `GradientHeader` с приветствием по времени суток (Xayrli tong / kun / kech) и именем;
  живая строка-итог («Bugun 1 240 kkal, 5 stakan suv, dorilar vaqtida ✓»); большое анимированное кольцо индекса с
  раскладкой по тапу; серия дней (индекс ≥ 60) и полоска «7 kun» цветными точками; поговорка дня
  (20 шт. в `assets/core/quotes.json`, uz + ru/en); дальше `allHomeCards`; всё с анимацией появления
- [x] S2-3 Достижения: 8 значков (первая тренировка, 7 дней воды, все лекарства вовремя 3 дня, первая бронь,
  10 000 шагов, индекс 90+ …); таблица `achievements` новой миграцией `*_core_achievements.sql` с RLS + GRANT;
  новое достижение — confetti; экран достижений в профиле (см. `profile/CLAUDE.md`)
- [x] S2-4 Недельный отчёт `/report` (`AppRoutes.report`): индекс по дням на fl_chart, лучший день, вода,
  тренировки, лекарства; «Ulashish» — карточка-картинка через screenshot + share_plus
- [x] S2-5 Онбординг 2.0: после входа — главная цель (похудеть / больше энергии / давление или сахар / забота о
  семье) → `profiles` (новой миграцией) → порядок карточек на главной; слайды в дизайне 2.0 (см. `onboarding/CLAUDE.md`)
- Проверка каждой задачи: эмулятор в обоих режимах (`env.json` и `USE_FAKE=true`)
