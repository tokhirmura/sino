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
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- Тесты: `test/features/vitals/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [ ]
