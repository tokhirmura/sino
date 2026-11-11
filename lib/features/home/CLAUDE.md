# Фича `home`

**Владелец:** модуль A (лид)

## Что делает
Главный экран: приветствие и карточки всех фич из `homeCardsProvider` (собираются в `feature_registry.dart`, сортировка по `order`).

## Маршруты
- `/home` (`AppRoutes.home`) — вкладка «Asosiy»

## Home-карточки
— нет (показывает чужие карточки через `homeCardsProvider`)

## Таблицы БД
— (читает `profiles` через `currentUserProvider`)

## Файлы
- `home_feature.dart` — единственный публичный файл (`homeRoutes`, `homeHomeCards`)
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- Тесты: `test/features/home/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [ ]
