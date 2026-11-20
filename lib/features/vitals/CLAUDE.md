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
- `application/vitals_providers.dart` — `vitalsWeekProvider(kind)`, `vitalsWeekAllProvider` (вся неделя одним
  запросом — экран и карточка), `latestVitalProvider(kind)`, `selectedVitalKindProvider`, `vitalsDevModeProvider`
  (prefs `vitals.dev_mode`), `vitalsActionsProvider` (`add`, `remove`, `fillTestHistory` → сколько добавлено)
- `presentation/vitals_screen.dart` — заголовок «Oxirgi 7 kun» (**5 быстрых тапов → режим разработчика**), плитки
  6 видов (последнее значение, точка статуса), график выбранного вида, измерения недели (удалить + «Qaytarish»),
  ИМТ, карточка разработчика «Test tarixini to‘ldirish (7 kun)», дисклеймер
- `presentation/widgets/vital_chart.dart` — шаги — столбцы с пунктиром 5000; остальное — линии, давление — две линии;
  зелёная полоса общей нормы
- `presentation/widgets/add_vital_sheet.dart` — вид, значение(я), проверка диапазона, нижнее давление < верхнего
- `presentation/widgets/bmi_card.dart` — рост из профиля, вес — последний замер (или из профиля), шкала 15…40
- `application/breathing.dart` — 4-7-8 без Flutter: `breathStateAt(elapsed, cycles)` → фаза, цикл, секунды (4…1),
  прогресс, `scale` круга (вдох 0.55→1 ease, задержка 1, выдох 1→0.55); 19 с на цикл, 4 / 6 / 8 циклов
- `presentation/breathing_screen.dart` — градиентный фон, светящийся круг (`Ticker`, плавно), большое число, фаза и
  подсказка, точки циклов, пауза / стоп, финал «Barakalla!» и «Yana bir bor», вибро-отклик на смену фазы; круг ≤ 38 %
  высоты — «Boshlash» видна на маленьком телефоне; вход — карточка на `/vitals` и на главной
- `presentation/vitals_home_card.dart`, `presentation/labels.dart`
- Тесты: `test/features/vitals/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] P0-1 Данные: модели `Vital`/`VitalKind`, репозиторий `vitals` (Supabase + Fake), провайдеры, тесты
- [x] P1-7 `/vitals`: пульс, шаги, сон, вес, давление (value/value2), сахар — записи в `vitals`
- [x] P1-7 Графики за 7 дней (`fl_chart`), калькулятор ИМТ, общие ориентиры нормы с дисклеймером
- [x] P1-7 Скрытая кнопка «заполнить тестовой историей» (только режим разработчика)
- [x] P2-9 Дыхательное упражнение 4-7-8 с анимацией круга (маршрут внутри фичи)
