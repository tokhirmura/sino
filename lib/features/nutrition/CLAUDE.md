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
- `nutrition`, order 50 — `NutritionHomeCard`: калории сегодня (кольцо, «X / цель kkal», «qoldi/ortiqcha»), вода
  «N / 8» с кнопкой «+1 stakan»; тап → вкладка на сегодня. Загрузка/ошибка — `ShortcutCard` с подписью

## Таблицы БД
`foods`, `food_logs` (+ `custom_food` jsonb, `food_id` nullable), `water_logs`. Edge Function `food-vision`.

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
- `presentation/nutrition_screen.dart` — экран дня (дизайн 2.0: `Scaffold` без AppBar, первым — `GradientHeader` с
  `DaySwitcher(onDark: true)` и `StatTile` «Yeyildi» (цифры плавно растут) / «Suv» л / «Maqsad»; загрузка —
  `SkeletonLoader`; пустой день — `EmptyState` с кнопкой «Taom qo‘shish»); `labels.dart` — названия приёмов пищи, даты, единицы;
  `widgets/` — `DaySwitcher`, `CalorieSummaryCard` (`AnimatedProgressRing`: бренд-градиент, сверх цели — шафран→терракота; число «qoldi» плавно
  меняется, ключ `nutrition-kcal-left`; БЖУ, non birligi, диалог цели), `WaterCard`,
  `MealSection` (порции ±0.5, свайп/корзина — удалить, «Qaytarish»), `add_food_sheet.dart` (поиск, приём, порция),
  `nutrition_home_card.dart` (карточка главной, те же `dayLogsProvider`/`waterProvider`, что и вкладка)
- `data/dasturxon.dart` — «Dasturxon» (S2-1): `HomeMeasure` (kosa, likopcha, dona, piyola, choy_qoshiq), `DasturxonItem`
  (slug, `food_id`, короткое имя `label` {uz,ru,en}, меры в граммах; первая — по умолчанию), `loadDasturxon`, `dasturxonServings(food, measure, count)` —
  граммы / граммы порции `foods` (до 0.01). Источник — `assets/wellness/dasturxon.json` (12 блюд), без таблицы: ссылается
  на `foods` по uuid, одинаково в fake и Supabase. `Food.portionGrams` — «300 g» → 300
- `application/nutrition_providers.dart` (ещё) — `dasturxonItemsProvider`, `dasturxonProvider` (блюда + строки каталога,
  порядок из JSON; нет в каталоге / порция не в граммах — пропуск)
- «Dasturxon» — быстрое добавление (S2-5): `presentation/widgets/dasturxon_card.dart` — `DasturxonCard` на экране под
  кольцом: 12 крупных кнопок (эмодзи + короткое имя `label` из JSON в одну строку, сжимается, не ломает слово), тап →
  `showDasturxonSheet`: приём пищи (чипы, по часам), для каждой меры — готовые количества `presetCounts` (kosa ½/1/2,
  likopcha ½/1/1½, dona 1–4, piyola 1–3, choy qoshiq 1–3) с ~ккал; **одно нажатие на количество — добавлено**
  (`dayLogsProvider.add`, SnackBar «Palov (osh) — 1 likopcha · Kechki ovqat»). `labels.dart` — `countText` (½, 1½),
  `measureText` (uz «2 dona», ru «2 миски / ½ тарелки», en «2 bowls»), `formatServings` до 0.01 (0.25 порции)
- Напоминания о воде (S2-7): `application/water_reminders.dart` — `waterReminderHours` (9, 11 … 21),
  `waterRemindersProvider` (prefs `nutrition.water_notify`, по умолчанию вкл.; `nutrition.water_notify_asked` —
  разрешение спрошено один раз, когда `WaterCard` показана впервые; `nutrition.water_notify_last` — язык
  запланированного или `off`, пересоздаёт только при изменении), `waterNotificationText`. `data/water_notifications.dart` —
  `LocalWaterNotifications` поверх общего `appNotificationsProvider` (`lib/core/notifications`): 7 ежедневных
  (`DateTimeComponents.time`, `nextLocalTime`) уведомлений, id `NotificationIds.wellnessBase + 100 + час`, payload
  `wellness:water`, канал `AppNotificationChannel.wellness`; Noop вне Android/iOS и в тестах выбирает core. В `WaterCard` — колокольчик
  `nutrition-water-notify` (вкл./выкл., SnackBar). ID модуля C ≥ 2 100 000 000 — не пересекаются с `reminders`
  (< 2 000 000 000, payload `reminder:`)
- **4 способа добавить еду** (лист «Ovqat qo‘shish» → 4 кнопки `nutrition-mode-*`; лист — один `CustomScrollView`):
  - Своя еда не из каталога: `Food.source` (`FoodSource.catalog|photo|recipe|barcode|quick`), `Food.custom(...)` (id
    `custom-…`), `isCustom`. В БД — `food_logs.food_id = null` + `custom_food` jsonb (миграция
    `20261121180000_wellness_custom_food.sql`, check: food_id или custom_food.kcal). `FoodLog.fromJson` берёт `foods`,
    иначе `custom_food`. Порция своей еды = съеденное количество (servings 1). Значок источника в строке дневника (`sourceBadge`).
    Home (`sino_data.dart`) считает kcal из `foods` или `custom_food`
  - 📷 **Rasmdan (beta)** — `presentation/photo_food_screen.dart`, `data/food_vision.dart`: `image_picker` (≤1024 px) →
    Edge Function `supabase/functions/food-vision` (Gemini/Claude с картинкой, те же секреты, что у `assistant`; деплой
    `npx supabase functions deploy food-vision --use-api`) → до 3 вариантов с % уверенности, ползунок граммов. Fake-режим или
    ошибка функции → `DemoFoodVisionRepository` (3 блюда каталога по байтам фото) с плашкой «Demo-taxmin». Фото не хранится
  - 👩‍🍳 **O‘zim pishirdim** — `presentation/recipe_screen.dart`, `data/ingredients.dart` (+ `assets/wellness/ingredients.json`,
    51 сырой продукт на 100 г, `piece_g`, алиасы uz/ru/en: префикс слова, `$` — слово целиком, длинный алиас побеждает).
    `parseRecipe(text)`: строки / запятые / «va, и, and, +»; число (1,5 · 1/2 · ½ · yarim · пол-) + единица (g, kg, ml, l,
    ta/dona/шт, osh/choy qoshiq, ст./ч. л., stakan, piyola, kosa, chimdim) в любом порядке; без количества — штука или 100 г
    с пометкой «?»; нераспознанное — плашка «Tanilmadi». Порции котла, «сколько съели», подсказка при > 40 % ккал из жира,
    примеры (palov/omlet/salat) на языке приложения. «Mening retseptlarim» — `myRecipesProvider` (prefs `nutrition.my_recipes`, ≤ 20)
  - 🏷️ **Shtrix-kod** — `presentation/barcode_food_screen.dart`, `data/products.dart`: камера `mobile_scanner` (EAN/UPC) или
    ввод кода, список «Mashhur mahsulotlar» (`assets/wellness/products.json`, 28 товаров на 100 г/мл: Rollton, батон, кола…).
    Поиск: запомненные (prefs `nutrition.products`) → assets → Open Food Facts (только не-fake, `productsHttpClientProvider`),
    найденное запоминается. Не найдено → «Yorliqdan kiritish» (ккал/БЖУ на 100, упаковка) → запоминается по коду.
    Карточка: «светофор» сахар/жир/соль (пороги UK FSA, для напитков — половина), Nutri-Score, состав; количество — пачка / ½ / 100 г / своё
  - ⚡ **Faqat kkal** — `widgets/quick_kcal_dialog.dart`: название (необяз.) + ккал (+ БЖУ)
  - «Yaqinda yeganlaringiz» — `recentFoodsProvider` (`latestLogs` → `recentFoods`, без повторов) — чипы в листе, одно нажатие
  - «Kechagidek» — в пустом приёме пищи кнопка `nutrition-repeat-<meal>`: добавить то же, что было днём раньше
  - `application/add_food_providers.dart` — провайдеры выше, `summarizeRecipe`, `recipeFood`, `searchProducts`;
    `widgets/add_food_parts.dart` — `ChoiceTile`, `NutrientLine`, `showNutritionSnack`
  - Тесты: `add_food_data_test.dart` (парсер, модели, товары + MockClient OFF, демо-фото, рецепты),
    `add_food_ui_test.dart` (все потоки), `add_food_screens_test.dart` (360×640, uz/ru/en × светлая/тёмная)
- `tool/wellness/gen_seed.dart` + `seed_sql.dart` — генератор seed-миграции каталогов
- Тесты: `test/features/nutrition/`; `module_c_screens_test.dart` — все экраны модуля C в uz/ru/en × светлая/тёмная
  на маленьком телефоне (без переполнения и узбекских строк в ru/en)
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] P0-1 Данные: `assets/wellness/foods.json` (40 блюд), seed-миграция, модели `fromJson/toJson`, репозиторий
  (каталог + `food_logs` + `water_logs`), провайдеры, юнит-тесты расчётов на Fake
- [x] P0-2 `/nutrition`: дневник дня по приёмам пищи (Nonushta, Tushlik, Kechki ovqat, Gazak), переключение даты
- [x] P0-2 Добавление/удаление еды из поиска, порции шагом 0.5, оптимистичное обновление UI
- [x] P0-2 Кольцо калорий к цели (Миффлин–Сан Жеор из профиля, цель можно поменять вручную), полоски БЖУ,
  «non birligi» (углеводы / 12)
- [x] P0-2 Вода — 8 стаканов в `water_logs`; простая подсказка по балансу дня
- [x] P0-4 `nutritionHomeCards`: калории и вода сегодня
- [x] P2-8 «Taomni rasmdan aniqlash»: `image_picker` + распознавание (Edge Function `food-vision`, офлайн — демо;
  анимация, 3 варианта, «beta»). Фото в Storage не сохраняем — не нужно для оценки (сделано лидом)
- [x] Ещё способы добавить (лид): «O‘zim pishirdim» (текст ингредиентов → КБЖУ), штрих-код (+ Open Food Facts),
  «Faqat kkal», «Yaqinda», «Kechagidek»

## Sprint 2.0
Номер задачи — из плана спринта (S2-1 … S2-7). Одна задача = один PR. Проверка экранов: телефон Android (USB),
эмулятор Android, симулятор iOS — в обоих режимах (`env.json` и `USE_FAKE=true`).
- [x] S2-1 «Dasturxon» — данные: `assets/wellness/dasturxon.json` (12 самых частых блюд × местные меры
  kosa / likopcha / dona / piyola / choy qoshiq → граммы), модель, пересчёт мера → порции `foods`, тесты
- [x] S2-2 Дизайн 2.0: `GradientHeader`, `StatTile`, `SkeletonLoader`, `EmptyState`, `PrimaryButton`, `flutter_animate`;
  кольцо калорий — `AnimatedProgressRing`, цифры плавно меняются при добавлении еды
- [x] S2-5 «Dasturxon» — быстрое добавление: 12 блюд крупными кнопками, выбор меры и количества (1 kosa, 2 dona),
  добавление в дневник одним нажатием
- [x] S2-7 Напоминание о воде каждые 2 ч (9:00–21:00), выключается в настройках
