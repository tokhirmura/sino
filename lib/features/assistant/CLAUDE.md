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
- [ ] P2-8 Чат на правилах по ключевым словам (uz, ru): головная боль, температура, простуда, желудок,
  давление, сон, стресс
- [ ] P2-8 Красные флаги (боль в груди, одышка, потеря сознания) → карточка «103 ga qo‘ng‘iroq qiling»
- [ ] P2-8 Кнопки-действия ведут в фичи (например `context.go(AppRoutes.pharmacySearch('ibuprofen'))`)
- [ ] P2-8 Дисклеймер «Shifokor maslahatini almashtirmaydi» вверху экрана
- [ ] P2-8 (опц.) Ответы LLM через Supabase Edge Function (ключ только в секретах функции); правила — запасной вариант
- [ ] P1-6 Тёмная тема и uz/ru/en
