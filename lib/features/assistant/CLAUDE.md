# Фича `assistant`

**Владелец:** модуль A (лид)

## Что делает
Ассистент здоровья: вопрос → подсказка и переход в нужную фичу (например `context.go(AppRoutes.pharmacySearch(q))`). Всегда дисклеймер «Shifokor maslahatini almashtirmaydi».

Чат на правилах (`assets/core/assistant_rules.json`, офлайн в обоих режимах):
- Темы: головная боль, температура, простуда, желудок, давление, сон, стресс. Красные флаги: боль в груди,
  одышка, потеря сознания, признаки инсульта → красная карточка «103 ga qo‘ng‘iroq qiling» с кнопкой звонка и SOS.
  Если сработал красный флаг, обычные советы не показываются.
- Ключевые слова на uz/ru/en, ответ — на языке интерфейса. Сравнение (`normalizeText` + `keywordHits`): нижний
  регистр, **апострофы убираются** (пишут и «og‘riyapti», и «ogriyapti»), ключ ищется с начала слова.
- Кнопки: `pharmacy` → `context.go(AppRoutes.pharmacySearch(query))`, `open` → вкладка `go`, иначе `push`,
  `call` → `tel:` (через `assistantLauncherProvider`, сам не звонит). Не понял — подсказки и «Shifokorga yozilish».
- Новая тема: добавить объект в JSON (тест проверяет 3 языка ответа и что маршруты существуют).

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
- [x] P2-8 Чат на правилах по ключевым словам (uz, ru): головная боль, температура, простуда, желудок,
  давление, сон, стресс
- [x] P2-8 Красные флаги (боль в груди, одышка, потеря сознания) → карточка «103 ga qo‘ng‘iroq qiling»
- [x] P2-8 Кнопки-действия ведут в фичи (например `context.go(AppRoutes.pharmacySearch('ibuprofen'))`)
- [x] P2-8 Дисклеймер «Shifokor maslahatini almashtirmaydi» вверху экрана
- [ ] P2-8 (опц.) Ответы LLM через Supabase Edge Function (ключ только в секретах функции); правила — запасной вариант.
  Не сделано: нужен ключ LLM в секретах и деплой функции лидом.
- [x] P1-6 Тёмная тема и uz/ru/en (проверяет `test/module_a_screens_test.dart`)
