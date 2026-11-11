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
- [ ] P0-4 Приветствие по имени из `profiles`
- [ ] P0-4 Карточка «индекс здоровья дня» (v1 — формула по данным профиля)
- [ ] P0-4 Сетка быстрых сервисов на все маршруты `AppRoutes`
- [ ] P0-4 Далее карточки `allHomeCards` (через `homeCardsProvider`); пустой список ничего не ломает
- [ ] P1-6 Тёмная тема и uz/ru/en
