# Фича `reminders`

**Владелец:** модуль B

## Что делает
Напоминания о приёме лекарств (для себя и членов семьи) через `flutter_local_notifications` + `timezone`, отметка «принял», история приёма.

## Маршруты
- `/reminders` (`AppRoutes.reminders`) — полноэкранный

## Home-карточки
- `reminders`, order 30

## Таблицы БД
`reminders`, `reminder_logs`

## Файлы
- `reminders_feature.dart` — единственный публичный файл (`remindersRoutes`, `remindersHomeCards`)
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- Тесты: `test/features/reminders/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [ ]
