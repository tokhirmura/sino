# Фича `sos`

**Владелец:** модуль A (лид)

## Что делает
Экстренная помощь: звонок 103 (`url_launcher` tel:), отправка геопозиции близким (sms:), краткая медкарта (группа крови, аллергии).

## Маршруты
- `/sos` (`AppRoutes.sos`) — полноэкранный

## Home-карточки
- `sos`, order 10

## Таблицы БД
— (читает `profiles`, `family_members`)

## Файлы
- `sos_feature.dart` — единственный публичный файл (`sosRoutes`, `sosHomeCards`)
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- Тесты: `test/features/sos/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [ ]
