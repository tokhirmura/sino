# Фича `vitals`

**Владелец:** модуль C

## Что делает
Ввод и графики показателей: пульс, шаги, сон, вес, давление (value/value2), сахар (`fl_chart`), подсветка выхода за
общие ориентиры нормы, калькулятор ИМТ, скрытое заполнение тестовой историей.

## Маршруты
- `/vitals` (`AppRoutes.vitals`) — полноэкранный
- `/vitals/breathing` (`vitalsBreathingPath`) — дыхание 4-7-8

## Home-карточки
- `vitals`, order 70 — `VitalsHomeCard`: «❤️ 71   🩺 118/76», «Me’yorda · Bugun 08:30» / красным «Me’yordan
  tashqarida»; без пульса и давления — приглашение внести первое измерение
- `steps`, order 72 — `StepsHomeCard` (S2-3): кольцо, «N / 8000», статус; тап → `/vitals`
- `breathing`, order 75 — «🌬️ 4-7-8 nafas mashqi» → `/vitals/breathing`

## Таблицы БД
`vitals`

## Файлы
- `vitals_feature.dart` — единственный публичный файл (`vitalsRoutes`, `vitalsHomeCards`)
- `data/models.dart` — `VitalKind` (pulse, steps, sleep, weight, pressure, glucose; единица и общие ориентиры
  нормы), `Vital` (`status` low/normal/high; неизвестный `kind` из БД пропускается), `VitalInput`
- `data/vitals_repository.dart` — `VitalsRepository` (`list`, `add`, `addAll` — одним запросом, `remove`) + Supabase +
  Fake (демо за 7 дней; сегодняшнее демо до 08:00 ставится «минуту назад», не в будущее)
- `application/vitals_math.dart` — `weekSeries` (7 точек, старые → сегодня; за день: шаги — максимум, вес и сон —
  последнее, остальное — среднее), `inputRange` (отсев опечаток), `bmi` / `bmiLevel` (18.5 / 25 / 30), `testHistory`
  (по одному реалистичному значению на каждый пустой день × вид за 7 дней; детерминированно; не в будущем)
- `application/vital_zones.dart` — зоны (S2-1, общая информация, не диагноз): `VitalZone` low / normal / elevated
  (yuqori me’yor) / high; давление (ESH) < 90 · 90–129 · 130–139 · ≥ 140 и < 60 · 60–84 · 85–89 · ≥ 90 — берётся
  более тревожное (`worse`: high > elevated > low > normal); сахар натощак < 3.9 · 3.9–5.5 · 5.6–6.9 · ≥ 7.0;
  `ZoneBand` (from ≤ v < to) — `systolicBands`, `diastolicBands`, `glucoseBands`, `chartBands(kind)` для графика;
  `zoneOf(vital)`. «Me’yor» совпадает со `status` normal. Тексты — `zoneText`, `zoneColor`, `zoneDisclaimer` в `labels.dart`
- `application/vitals_providers.dart` — `vitalsWeekProvider(kind)`, `vitalsWeekAllProvider` (вся неделя одним
  запросом — экран и карточка), `latestVitalProvider(kind)`, `selectedVitalKindProvider`, `vitalsDevModeProvider`
  (prefs `vitals.dev_mode`), `vitalsActionsProvider` (`add`, `remove`, `fillTestHistory` → сколько добавлено)
- `presentation/vitals_screen.dart` — заголовок «Oxirgi 7 kun» (**5 быстрых тапов → режим разработчика**), плитки
  6 видов (последнее значение, точка статуса), график выбранного вида, измерения недели (удалить + «Qaytarish»),
  ИМТ, карточка разработчика «Test tarixini to‘ldirish (7 kun)», дисклеймер; дизайн 2.0: загрузка —
  `SkeletonLoader(grid)`, нет измерений вида — `EmptyState` «O‘lchov qo‘shish», в листе ввода — `PrimaryButton`
- `presentation/widgets/vital_chart.dart` — шаги — столбцы с пунктиром 5000; остальное — линии, давление — две линии;
  зелёная полоса общей нормы
- `presentation/widgets/add_vital_sheet.dart` — вид, значение(я), проверка диапазона, нижнее давление < верхнего
- `presentation/widgets/bmi_card.dart` — рост из профиля, вес — последний замер (или из профиля), шкала 15…40
- `application/breathing.dart` — 4-7-8 без Flutter: `breathStateAt(elapsed, cycles)` → фаза, цикл, секунды (4…1),
  прогресс, `scale` круга (вдох 0.55→1 ease, задержка 1, выдох 1→0.55); 19 с на цикл, 4 / 6 / 8 циклов
- `presentation/breathing_screen.dart` — градиентный фон (`AppColors.brandGradientDark`, свечение — `primary`), светящийся круг (`Ticker`, плавно), большое число, фаза и
  подсказка, точки циклов, пауза / стоп, финал «Barakalla!» и «Yana bir bor», вибро-отклик на смену фазы; круг ≤ 38 %
  высоты — «Boshlash» видна на маленьком телефоне; вход — карточка на `/vitals` и на главной
- Шаги (S2-3):
  - `data/step_sensor.dart` — `StepSensor` (`counts()` — накопленные шаги с перезагрузки, `openSettings()`),
    `PedometerStepSensor` (`pedometer`; одинаково в fake и Supabase — это железо), `FakeStepSensor` для тестов,
    `StepSensorUnavailable` (нет датчика / эмулятор). iOS сам спрашивает Motion (`NSMotionUsageDescription` есть).
    **Android 10+**: `ACTIVITY_RECOGNITION` в манифесте есть, но запросить его из Dart без `permission_handler` нельзя
    (пакета нет в pubspec — попросили лида). Пока: без разрешения Android молчит → через 5 с статус `silent` и кнопка
    «Ruxsat berish» → `Geolocator.openAppSettings()`; при возврате в приложение — `restart()`
  - `application/steps.dart` — без Flutter: `StepsDay` (день, baseline, last, carried; JSON в prefs), `applyStepCount`
    (первое чтение дня = 0, перезагрузка телефона — сумма сохраняется, новый день — вчера `finished`), `shouldSaveSteps`
    (раз в 5 мин или +500 шагов), `stepsGoal` = 8000, ~км (0.75 м/шаг), ~ккал (0.04/шаг)
  - `application/steps_providers.dart` — `stepsProvider` (`StepsNotifier` → `StepsView` starting / counting / silent /
    unavailable + шаги): prefs `vitals.steps_day`; итог дня → `vitals` kind `steps`, **одна строка на день**,
    обновляется на месте (`VitalsRepository.update`; удалена пользователем — новая), prefs `vitals.steps_row`;
    закончившийся день — `measured_at` 23:59; офлайн / не вошёл — тихо пропускает; `flush()` при уходе в фон
  - `presentation/widgets/steps_card.dart` — `StepsCard` (вверху `/vitals`: `AnimatedProgressRing` с плавным числом,
    ~км/~ккал, «Maqsadgacha N qadam» / «Maqsad bajarildi! 🎉», подсказки silent/unavailable) и `StepsHomeCard`;
    оба слушают жизненный цикл (фон → `flush`, возврат → `restart`)
- `data/vitals_repository.dart` (ещё) — `update(id, value:, measuredAt:)` → `false`, если строки нет
- `presentation/vitals_home_card.dart`, `presentation/labels.dart`
- Тесты: `test/features/vitals/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] P0-1 Данные: модели `Vital`/`VitalKind`, репозиторий `vitals` (Supabase + Fake), провайдеры, тесты
- [x] P1-7 `/vitals`: пульс, шаги, сон, вес, давление (value/value2), сахар — записи в `vitals`
- [x] P1-7 Графики за 7 дней (`fl_chart`), калькулятор ИМТ, общие ориентиры нормы с дисклеймером
- [x] P1-7 Скрытая кнопка «заполнить тестовой историей» (только режим разработчика)
- [x] P2-9 Дыхательное упражнение 4-7-8 с анимацией круга (маршрут внутри фичи)

## Sprint 2.0
Номер задачи — из плана спринта (S2-1 … S2-7). Одна задача = один PR. Проверка экранов: телефон Android (USB),
эмулятор Android, симулятор iOS — в обоих режимах (`env.json` и `USE_FAKE=true`).
- [x] S2-1 Зоны давления и сахара: past / me’yor / yuqori me’yor / baland (общая информация, не диагноз) — функции
  расчёта, полосы зон для графика, тесты
- [x] S2-2 Дизайн 2.0: `GradientHeader`, `StatTile`, `SkeletonLoader`, `EmptyState`, `PrimaryButton`, `flutter_animate`
- [x] S2-3 Шаги: `pedometer` — реальные шаги за сегодня, цель 8000, кольцо; итог дня → `vitals` (kind = 'steps',
  лид берёт в индекс Sino); запрос разрешения, понятный текст при отказе; проверить на телефоне (эмулятор не считает)
- [ ] S2-6 Давление и сахар 2.0: цветные зоны на графике, последние 30 дней, «Shifokorga yuborish» — скриншот графика
  и таблицы через `share_plus`, дисклеймер «Shifokor maslahatini almashtirmaydi»
