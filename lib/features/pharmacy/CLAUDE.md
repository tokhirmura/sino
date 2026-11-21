# Фича `pharmacy`

**Владелец:** модуль B

## Что делает
Поиск лекарств (по названию, действующему веществу, штрих-коду через `mobile_scanner`), аналоги, цены по аптекам, карта аптек (`flutter_map`, `geolocator`), бронирование с прикреплением рецепта (`image_picker`), статус брони в реальном времени.

Каталоги модуля B: источник — `assets/pharmacy/medicines.json`, `pharmacies.json`, `pharmacy_stock.json`,
`doctors.json` (формат таблиц; `slug` — только в assets, в БД не пишется). `id` — фиксированные uuid, общие для
assets, Fake и Supabase: `a1000000-…` лекарства, `a2000000-…` аптеки, `a3000000-…` остатки, `a4000000-…` врачи.
После правки JSON: `dart run tool/pharmacy/gen_seed.dart` → перегенерирует
`supabase/migrations/20261117120000_pharmacy_seed.sql` (тест сверяет файл с assets). Миграции пушит лид.
Fake-режим: пользовательские данные в prefs (`pharmacy.fake_reservations`, `reminders.fake_*`,
`doctors.fake_appointments`), при первом чтении — демо из `assets/pharmacy/fake_pharmacy.json` (даты относительно
сегодня, члены семьи — id из core `FamilyMember.fakes`: `fake-mother`, `fake-father`, `fake-daughter`).

## Решения по схеме
- **`medicines.analogs`** — `text[]` из **id** (uuid) других строк каталога с **тем же действующим веществом**
  (дженерики: Paracetamol ↔ Panadol ↔ Efferalgan). Другое вещество аналогом не считается никогда — замену
  назначает врач. Список симметричный, не содержит саму запись (проверяет тест). `analogsProvider` дополнительно
  добавляет строки с тем же `ingredient` (на случай строк в БД без списка) и сортирует от дешёвых.
- **`ingredient`** — по-английски, нижний регистр, несколько веществ через ` + `
  (`amoxicillin + clavulanic acid`) — по нему считаются аналоги.
- **`name`** — торговое название с дозировкой (`Nurofen 200 mg`), не переводится (колонка `text`).
- **`form`** — слаг из `medicineForms` (`tablet|capsule|syrup|powder|spray|drops|ointment`), **`category`** — из
  `medicineCategories` (`pain|cold|allergy|stomach|heart|diabetes|antibiotic|vitamins|skin|eye|nerves`).
  Подписи uz/ru/en — в `presentation/`.
- **`barcode`** — EAN-13 с контрольной цифрой (демо-коды `4781000…`).
- **Цены:** `medicines.price_uzs` — справочная; реальная — `pharmacy_stock.price_uzs` по аптеке.
  `qty = 0` — «нет в наличии» (показываем серым, бронь запрещена).
- **`reservations.rx_attached`** — только флаг: фото рецепта остаётся на устройстве (в таблице нет колонки под
  файл, Storage-бакета нет). Нужно хранить фото на сервере → попросить лида core-миграцию (бакет + политики).
- **Статусы брони:** `pending → ready → picked` двигает аптека, пользователь может только отменить
  (`pending|ready → cancelled`). Supabase — realtime-стрим `reservations` (публикация уже включена); Fake имитирует
  аптеку: `pending` → `ready` через 20 с (`FakePharmacyRepository.readyAfter`, в тестах `null`).
  Остатки при брони не уменьшаются (каталог — только select).
- **Поиск** — на устройстве (каталог маленький, одинаково в Fake и Supabase): название, вещество, slug, штрих-код и
  описание на 3 языках (работает «isitma», «температура»). Апострофы игнорируются, кириллица транслитерируется
  («ибупрофен» → Ibuprofen). Порядок: начало названия → название → вещество/штрих-код → описание.
- **Геопозиция** — своя `UserLocationRepository` (импортировать `sos` нельзя); нет доступа → `null`, сортировка по
  цене, карта по центру Ташкента (`tashkentCenter`). Fake — Ташкент.

## Экраны
- **Поиск** (вкладка): поле с поиском по мере ввода (250 мс), очистка, сканер; без запроса — баннер активных броней,
  чипы категорий, весь каталог. Новый `?q=` при уже открытой вкладке заменяет запрос (`didUpdateWidget`).
  Штрих-код: найден → карточка лекарства, нет → запрос = код + сообщение.
- **Лекарство**: заголовок (форма, категория, рецепт), дисклеймер «Shifokor maslahatini almashtirmaydi», описание,
  предупреждение, цены по аптекам (Arzon / Yaqin — «Yaqin» доступно, когда известна геопозиция), аналоги с лучшей ценой
  (тап — `pushReplacement`, без стопки экранов).
- **Бронь** (bottom sheet): для себя / члена семьи, фото рецепта — камера или галерея (обязательно для `rx`,
  иначе по желанию), «Bron qilish · цена». Фото — локальный путь в prefs `pharmacy.rx_photos`
  (`reservation id → path`, `rxPhotosProvider`); пропал файл — заглушка.
- **Bronlarim**: активные и история, статус вживую; у `pending` — полоса прогресса, при переходе
  `pending → ready` — snackbar; отмена с подтверждением, «Yo‘nalish» открывает карты.
- **Dorixonalar**: список (ближние первыми, расстояние, рейтинг) / карта `flutter_map` (тайлы OpenStreetMap —
  нужен интернет; маркеры и список работают офлайн), фильтр 24/7, шторка с «Yo‘nalish».
- **Сканер**: `mobile_scanner` (EAN-13/8, UPC), фонарик; ввод кода вручную всегда доступен (эмулятор, нет камеры).
- **Home-карточка**: «Olib ketishga tayyor: N» / «Faol bronlar: N» → «Bronlarim», иначе — вкладка.

## Маршруты
- `/pharmacy` (`AppRoutes.pharmacy`) — вкладка «Dorixona»
- Контракт: `/pharmacy?q=<запрос>` → `PharmacyScreen(initialQuery: q)` — поиск с готовым запросом
  (ассистент шлёт `ibuprofen`, `paracetamol` — тест проверяет, что они находятся)
- Подэкраны поверх NavigationBar (`presentation/pharmacy_paths.dart`): `/pharmacy/medicine/:id`,
  `/pharmacy/pharmacies`, `/pharmacy/reservations`, `/pharmacy/scan` (возвращает код через `pop`)

## Home-карточки
- `pharmacy`, order 40

## Таблицы БД
`medicines`, `pharmacies`, `pharmacy_stock`, `reservations` (realtime)

## Файлы
- `pharmacy_feature.dart` — единственный публичный файл (`pharmacyRoutes`, `pharmacyHomeCards`)
- `data/models.dart` — `Medicine`, `Pharmacy`, `StockItem` (join `pharmacies(*)`), `Reservation` (+ `resolve` из
  каталога — у realtime-строк нет join), `ReservationStatus`, `medicineForms`, `medicineCategories`
- `data/pharmacy_repository.dart` — `PharmacyRepository` + Supabase + Fake, `searchMedicines`, `normalizeMedicineText`
- `data/location_repository.dart` — `UserLocationRepository` (geolocator / Fake), `tashkentCenter`
- `application/pharmacy_providers.dart` — `medicinesCatalogProvider`, `medicinesByIdProvider`, `pharmaciesProvider`,
  `pharmaciesByIdProvider`, `medicineSearchProvider(q)`, `medicineByBarcodeProvider(code)`, `analogsProvider(id)`,
  `userLocationProvider`, `medicineOffersProvider(id)` (`StockOffer`: аптека, цена, наличие, км; `sortOffers` по цене
  или расстоянию, в наличии — первыми), `bestPriceProvider(id)`, `nearbyPharmaciesProvider`,
  `reservationsProvider` (`ReservationsNotifier`, `StreamNotifier`: оптимистичные `reserve(offer)` / `cancel(id)`,
  откат и rethrow; правила — `ReservationException`: `rxRequired`, `outOfStock`, `alreadyActive`, `notCancellable`),
  `activeReservationsProvider`
- `data/rx_photo.dart` — `RxPhotoPicker` (`image_picker`), `rxPhotosProvider` (локальные фото рецептов)
- `data/external_launcher.dart` — `pharmacyLauncherProvider` (карты через `url_launcher`), `pharmacyMapsUri`,
  `pharmacyMapTilesProvider` (в тестах `false`)
- `presentation/` — `pharmacy_screen.dart`, `medicine_screen.dart`, `reservations_screen.dart`,
  `pharmacies_screen.dart`, `scan_screen.dart`, `labels.dart` (форма, категория, статус, расстояние, часы),
  `widgets/common.dart` (`MedicalDisclaimer`, `Tag` — как core `Pill`, но с многоточием, `RxPill`, `MedicineTile`, `OfferTile`, тексты ошибок брони),
  `widgets/reserve_sheet.dart` (`showReserveSheet`, `RxThumbnail`)
- `application/write_queue.dart` — очередь записей и `pending-…` id (копия есть в reminders и doctors — фичи не
  импортируют друг друга)
- `tool/pharmacy/gen_seed.dart` + `seed_sql.dart` — генератор seed-миграции каталогов модуля B
- Fake читает assets через `bundle.load` + `utf8.decode`, не `loadString`: тот декодирует файлы > 50 КБ
  (`pharmacy_stock.json`) в изоляте через `compute`, и в widget-тестах это не завершается.
- Тема делает FilledButton / OutlinedButton во всю ширину — в `Row` задавайте `minimumSize` или `Expanded`.
- Тесты: `test/features/pharmacy/` — `pharmacy_screens_test.dart` гоняет экраны под настоящим `GoRouter`
  (поиск, лекарство, бронь `pending → ready` по таймеру, рецепт, отмена, список/карта, сканер, home-карточка)
  и каждый экран + home-карточку в uz/ru/en × светлая/тёмная на 320×568 с шрифтом ×1.3 (в тестах с `ProviderContainer` сначала `container.listen(...)`, потом
  `read(...future)`: Riverpod 3 ставит на паузу провайдеры без слушателей, а офферы пересобираются при получении
  геопозиции)
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Нужно от лида
- `supabase db push` для `supabase/migrations/20261117120000_pharmacy_seed.sql` (каталоги модуля B: лекарства,
  аптеки, остатки, врачи).

## Чеклист задач
- [x] Данные: каталоги в `assets/pharmacy/` (41 лекарство, 11 аптек, 360 строк остатков, 16 врачей),
  seed-миграция + генератор, модели, репозиторий (Supabase + Fake с имитацией аптеки), провайдеры, тесты
- [x] `/pharmacy`: поиск с `initialQuery`, карточка лекарства (описание, предупреждение, аналоги, дисклеймер)
- [x] Цены по аптекам (сортировка цена / расстояние) и карта аптек (`flutter_map`)
- [x] Сканер штрих-кода (`mobile_scanner`) → `medicineByBarcodeProvider`, ручной ввод
- [x] Бронь: для себя / члена семьи, фото рецепта для `rx` (`image_picker`), список броней со статусом вживую
- [x] `pharmacyHomeCards`: активные брони
- [x] Тёмная тема и uz/ru/en (проверяет `pharmacy_screens_test.dart`: 3 языка × 2 темы, 320×568, шрифт ×1.3)
- Текст цветом бренда — `colorScheme.primary` или `AppColors.readable(...)`, не голый `AppColors.primary`.
