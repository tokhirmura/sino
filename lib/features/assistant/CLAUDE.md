# Фича `assistant`

**Владелец:** модуль A (лид)

## Что делает
Ассистент здоровья: вопрос → подсказка и переход в нужную фичу (например `context.go(AppRoutes.pharmacySearch(q))`). Всегда дисклеймер «Shifokor maslahatini almashtirmaydi».

## Маршруты
- `/assistant` (`AppRoutes.assistant`) — полноэкранный

## Home-карточки
- `assistant`, order 90

## Таблицы БД
—

## Файлы
- `assistant_feature.dart` — единственный публичный файл (`assistantRoutes`, `assistantHomeCards`)
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- Тесты: `test/features/assistant/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [ ]
