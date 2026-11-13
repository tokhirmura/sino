# Фича `vitals`

**Владелец:** модуль C

## Что делает
Ввод и графики показателей: давление (value/value2), пульс, сахар, вес, температура (`fl_chart`), подсветка выхода за норму.

## Маршруты
- `/vitals` (`AppRoutes.vitals`) — полноэкранный

## Home-карточки
- `vitals`, order 70

## Таблицы БД
`vitals`

## Файлы
- `vitals_feature.dart` — единственный публичный файл (`vitalsRoutes`, `vitalsHomeCards`)
- `data/models.dart` — `VitalKind` (pulse, steps, sleep, weight, pressure, glucose; единица и общие ориентиры
  нормы), `Vital` (`status` low/normal/high; неизвестный `kind` из БД пропускается)
- `data/vitals_repository.dart` — `VitalsRepository` + Supabase + Fake (демо за 7 дней)
- `application/vitals_providers.dart` — `vitalsWeekProvider(kind)`, `latestVitalProvider(kind)`
- Тесты: `test/features/vitals/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] P0-1 Данные: модели `Vital`/`VitalKind`, репозиторий `vitals` (Supabase + Fake), провайдеры, тесты
- [ ] P1-7 `/vitals`: пульс, шаги, сон, вес, давление (value/value2), сахар — записи в `vitals`
- [ ] P1-7 Графики за 7 дней (`fl_chart`), калькулятор ИМТ, общие ориентиры нормы с дисклеймером
- [ ] P1-7 Скрытая кнопка «заполнить тестовой историей» (только режим разработчика)
- [ ] P2-9 Дыхательное упражнение 4-7-8 с анимацией круга (маршрут внутри фичи)
