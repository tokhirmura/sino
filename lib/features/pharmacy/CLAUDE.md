# Фича `pharmacy`

**Владелец:** модуль B

## Что делает
Поиск лекарств (по названию, действующему веществу, штрих-коду через `mobile_scanner`), аналоги, цены по аптекам, карта аптек (`flutter_map`, `geolocator`), бронирование с прикреплением рецепта (`image_picker`), статус брони в реальном времени.

## Маршруты
- `/pharmacy` (`AppRoutes.pharmacy`) — вкладка «Dorixona»
- Контракт: `/pharmacy?q=<запрос>` → `PharmacyScreen(initialQuery: q)` — поиск с готовым запросом

## Home-карточки
- `pharmacy`, order 40

## Таблицы БД
`medicines`, `pharmacies`, `pharmacy_stock`, `reservations` (realtime)

## Файлы
- `pharmacy_feature.dart` — единственный публичный файл (`pharmacyRoutes`, `pharmacyHomeCards`)
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- Тесты: `test/features/pharmacy/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [ ]
