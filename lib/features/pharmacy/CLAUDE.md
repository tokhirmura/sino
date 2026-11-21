# Фича `pharmacy`

**Владелец:** модуль B

## Что делает
Поиск лекарств (по названию, действующему веществу, штрих-коду через `mobile_scanner`), аналоги, цены по аптекам, карта аптек (`flutter_map`, `geolocator`), бронирование с прикреплением рецепта (`image_picker`), статус брони в реальном времени.

Каталоги модуля B: источник — `assets/pharmacy/medicines.json`, `pharmacies.json`, `pharmacy_stock.json`,
`doctors.json` (формат таблиц; `slug` — только в assets, в БД не пишется). `id` — фиксированные uuid, общие для
assets, Fake и Supabase: `a1000000-…` лекарства, `a2000000-…` аптеки, `a3000000-…` остатки, `a4000000-…` врачи.
После правки JSON: `dart run tool/pharmacy/gen_seed.dart` → перегенерирует
`supabase/migrations/20261117120000_pharmacy_seed.sql` (тест сверяет файл с assets). Миграции пушит лид.
Fake-режим: пользовательские данные в prefs (`pharmacy.fake_reservations`, `pharmacy.fake_home_meds`, `reminders.fake_*`,
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
- **Design 2.0 (Sprint 2.0 B+):** вкладка — `GradientHeader` (поиск + `StatTile` «Dorilar» / «Faol bronlar»),
  скелетоны `SkeletonLoader`, `EmptyState(actionLabel:)`, каскадное появление карточек — `widgets/motion.dart`
  (`staggerIn(i)`, задержки внутри эффектов `flutter_animate`, без таймеров; учитывает «уменьшить движение»).
- **3 шага брони** `Qabul qilindi → Tayyorlanmoqda → Tayyor` — `widgets/reservation_steps.dart`
  (`reservationProgress`: отправка 0, `pending` 1, `ready` 3; только конечные анимации) — в карточке брони,
  в баннере вкладки и в home-карточке (`widgets/active_reservation_card.dart`, `dense` на главной).
- **«Wow» при готовности:** `application/ready_celebrations.dart` — очередь переходов `pending → ready`;
  `ReadyCelebrationHost` (вкладка, «Bronlarim», home-карточка) показывает полноэкранный баннер
  (`widgets/ready_celebration.dart`: конфетти, `HapticFeedback.heavyImpact`, «Yo‘nalish»). Хостов может быть
  несколько — переход показывается один раз (`take()` после кадра).
  Тесты: `confetti` двигает частицы по реальному `DateTime.now()`, под тестовыми часами он не завершается —
  закрывайте баннер («Ajoyib!») до `pumpAndSettle`.
- **Rx-бейдж** `RxBadge` («Retsept kerak» / «Retseptsiz»): сплошная заливка, белый текст ≥ 4.5:1; большой — в
  шапке лекарства, `compact` — в строках списка.
- **Карта:** пины `PharmacyPin` (градиент бренда, 24/7 — зелёные, выбранный крупнее с шафрановой обводкой);
  тап → карточка аптеки выезжает снизу (`AnimatedSwitcher` + `SlideTransition`), тап по карте / ✕ — закрыть.
- **Uy dorixonasi** (`/pharmacy/home-meds`, вход — карточка на вкладке и «Uy dorixonasiga qo‘shish» на лекарстве):
  домашние лекарства со сроком годности, отсортированы по сроку. Бейдж `ExpiryBadge`: истёк / ≤ 30 дней
  (`expiryWarningDays`) — сплошной гранат/шафран, белый текст ≥ 4.5:1; иначе «Yaroqli» / «Muddati kiritilmagan».
  Добавление (`HomeMedSheet`): из каталога (подсказки), по штрих-коду (`homeMedsScannerProvider` → `/pharmacy/scan`)
  или вручную; срок, количество 0–999, заметка; правка и удаление с «Qaytarish». «Buyurtma berish» (истёк / скоро /
  0 шт.) и «Qayta buyurtma» → `context.go(AppRoutes.pharmacySearch(name))`. Дни считаются по датам в UTC
  (без сдвига DST); часы — `homeMedsClockProvider` (в тестах фиксируется).
- **Поиск** (вкладка): поле с поиском по мере ввода (250 мс), очистка, сканер; без запроса — баннер активных броней,
  чипы категорий, весь каталог. Новый `?q=` при уже открытой вкладке заменяет запрос (`didUpdateWidget`).
  Штрих-код: найден → карточка лекарства, нет → запрос = код + сообщение.
- **Лекарство**: заголовок (форма, категория, рецепт), дисклеймер «Shifokor maslahatini almashtirmaydi», описание,
  предупреждение, цены по аптекам (Arzon / Yaqin — «Yaqin» доступно, когда известна геопозиция), аналоги с лучшей ценой
  (тап — `pushReplacement`, без стопки экранов).
- **Бронь** (bottom sheet): для себя / члена семьи, фото рецепта — камера или галерея (обязательно для `rx`,
  иначе по желанию), «Bron qilish · цена». Фото — локальный путь в prefs `pharmacy.rx_photos`
  (`reservation id → path`, `rxPhotosProvider`); пропал файл — заглушка.
- **Bronlarim**: активные и история, статус вживую; у активных — 3 шага `ReservationSteps`, при переходе
  `pending → ready` — полноэкранный баннер (`ReadyCelebrationHost`); отмена с подтверждением, «Yo‘nalish» — карты.
- **Dorixonalar**: список (ближние первыми, расстояние, рейтинг) / карта `flutter_map` (тайлы OpenStreetMap —
  нужен интернет; маркеры и список работают офлайн), фильтр 24/7, шторка с «Yo‘nalish».
- **Сканер**: `mobile_scanner` (EAN-13/8, UPC), фонарик; ввод кода вручную всегда доступен (эмулятор, нет камеры).
- **Home-карточка**: есть активные брони — `ActiveReservationsCard(dense: true)` с 3 шагами → «Bronlarim»,
  иначе — «Dori qidirish va bron qilish» → вкладка. Тоже хост баннера готовности.

## Маршруты
- `/pharmacy` (`AppRoutes.pharmacy`) — вкладка «Dorixona»
- Контракт: `/pharmacy?q=<запрос>` → `PharmacyScreen(initialQuery: q)` — поиск с готовым запросом
  (ассистент шлёт `ibuprofen`, `paracetamol` — тест проверяет, что они находятся)
- Подэкраны поверх NavigationBar (`presentation/pharmacy_paths.dart`): `/pharmacy/medicine/:id`,
  `/pharmacy/pharmacies`, `/pharmacy/reservations`, `/pharmacy/scan` (возвращает код через `pop`),
  `/pharmacy/home-meds`

## Home-карточки
- `pharmacy`, order 40

## Таблицы БД
`medicines`, `pharmacies`, `pharmacy_stock`, `reservations` (realtime), `home_meds`
(`20261121160000_pharmacy_home_meds.sql`: RLS `user_id = auth.uid()`, GRANT authenticated + service_role;
`medicine_id` → `medicines` `on delete set null`, вручную — только `name`)

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
- `data/home_meds_repository.dart` — `HomeMed`, `HomeMedsRepository` + Supabase + Fake, `homeMedsClockProvider`
- `application/home_meds_providers.dart` — `homeMedsProvider` (оптимистичные add / edit / remove, `HomeMedException`),
  `homeMedsSummaryProvider`, `expiryState`, `daysUntilExpiry`, `sortHomeMeds`
- `data/rx_photo.dart` — `RxPhotoPicker` (`image_picker`), `rxPhotosProvider` (локальные фото рецептов)
- `data/external_launcher.dart` — `pharmacyLauncherProvider` (карты через `url_launcher`), `pharmacyMapsUri`,
  `pharmacyMapTilesProvider` (в тестах `false`)
- `presentation/` — `pharmacy_screen.dart`, `medicine_screen.dart`, `reservations_screen.dart`,
  `pharmacies_screen.dart`, `scan_screen.dart`, `labels.dart` (форма, категория, статус, расстояние, часы),
  `home_meds_screen.dart`, `widgets/common.dart` (`MedicalDisclaimer`, `Tag` — как core `Pill`, но с многоточием, `RxBadge`, `MedicineTile`, `OfferTile`, тексты ошибок брони),
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
- `supabase db push` для `supabase/migrations/20261121160000_pharmacy_home_meds.sql` (таблица `home_meds`).
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

**Sprint 2.0 B+**
- [x] Баг-фиксы лида: контраст бирюзового текста, переполнение на 320×568 / шрифт ×1.3 (светлая и тёмная)
- [x] Design 2.0: `GradientHeader` + `StatTile` на вкладке, `SkeletonLoader`, `EmptyState` с действием,
  `PrimaryButton`, каскад карточек, крупный `RxBadge`, пины карты в цветах бренда, выезжающая карточка аптеки
- [x] «Wow» брони: 3 шага `Qabul qilindi → Tayyorlanmoqda → Tayyor` (карточка брони, баннер вкладки,
  home-карточка), баннер на весь экран + конфетти + вибрация при `pending → ready`
- [x] Uy dorixonasi: `home_meds` (миграция, Supabase + Fake), срок с предупреждением за 30 дней, каталог/штрих-код,
  «Qayta buyurtma» → `/pharmacy?q=` (`test/features/pharmacy/home_meds_test.dart`)
- [x] Передача лиду (этот раздел)
- Не успели: — (всё из Sprint 2.0 B+ сделано)

- Текст цветом бренда — `colorScheme.primary` или `AppColors.readable(...)`, не голый `AppColors.primary`.

## Для лида (Sprint 2.0 B+, ветка `feat/module-b-v2`)

**Сделано:** см. «Чеклист задач → Sprint 2.0 B+». Всё работает офлайн (fake) и с Supabase; `flutter test` — зелёный.

**Нужно сделать лиду**
1. `supabase db push` — новая миграция `20261121160000_pharmacy_home_meds.sql` (таблица `home_meds`, RLS,
   GRANT). Без неё экран «Uy dorixonasi» в Supabase-режиме покажет ошибку с «Qayta urinish» (fake работает).
2. Если ещё не применена — `20261117120000_pharmacy_seed.sql` (каталоги лекарств, аптек, остатков, врачей).

**Известные ограничения**
- Фото рецепта хранится **только на устройстве** (`pharmacy.rx_photos`); в БД — флаг `rx_attached`. Для хранения на
  сервере нужна core-миграция (Storage-бакет + политики).
- Статус брони в Supabase двигает «аптека» — панели аптеки нет, для демо меняйте статус SQL-запросом (ниже).
  RLS `reservations_own` разрешает пользователю `update` своих строк целиком — приложение меняет только на
  `cancelled`, но строгая защита статуса потребует триггер/политику (core-миграция).
- Баннер «Bron tayyor!» показывается, только если в момент перехода открыт один из хостов: вкладка «Dorixona»,
  «Bronlarim» или главная (home-карточка аптеки). Если приложение было свёрнуто — статус обновится, баннера не будет.
- Остатки в аптеках при брони не уменьшаются (каталог — только select). Тайлы карты — из интернета (OSM);
  маркеры и список работают офлайн.
- Конфетти отключается при системном «уменьшить движение»; вибрация — только на реальном устройстве.
- Тесты: `confetti` не завершается под тестовыми часами — закрывайте баннер («Ajoyib!») до `pumpAndSettle`.
- Тест module C `workout_player_test.dart` тапает карточку тренировок на главной без прокрутки; карточка аптеки
  на главной сделана компактной (`dense`), чтобы его не сдвинуть. Стоит добавить там `ensureVisible`.

**Демо жюри: живая бронь → «Tayyor» + конфетти + 3 шага**

*Вариант A — офлайн (рекомендуем, не зависит от сети):* fake-аптека сама переводит бронь в `ready` через 20 с.
1. Реальный Android/iOS (ради вибрации), в системе выключено «уменьшить движение / убрать анимации».
2. Чистое демо: удалить приложение или «Очистить данные», затем `flutter run --release --dart-define=USE_FAKE=true`.
   Демо-данные создаются сами при первом запуске из `assets/pharmacy/fake_pharmacy.json`: Ibuprofen в «Shifo» —
   уже `ready`, Amlodipin — выдан, 5 домашних лекарств (Smekta — просрочена, Ibuprofen — 18 дней).
3. Пройти анкету (любые данные; главная цель меняет порядок карточек на главной — карточка «Dorixona» может
   оказаться ниже) → вкладка «Dorixona».
4. Поиск «Paracetamol» (без рецепта — фото не нужно) → лекарство → любая аптека из «Dorixonalardagi narxlar» → «Bron qilish · …».
   **Не берите Ibuprofen в «Shifo»** — там уже активная бронь (ошибка «Bu dori shu dorixonada allaqachon bron qilingan»).
5. Сразу видно: в баннере вкладки 3 шага — «Qabul qilindi ✓ → Tayyorlanmoqda … → Tayyor».
   Можно показать то же в «Bronlarim» и на главной (карточка «Dorixona»).
6. **Оставайтесь** на вкладке «Dorixona», в «Bronlarim» или на главной. Через ~20 с: вибрация, баннер на весь экран
   «Bron tayyor! 🎉», конфетти, шаги «Tayyor». «Yo‘nalish» открывает карты, «Ajoyib!» — закрыть.
7. Повтор: отменить бронь в «Bronlarim» и забронировать снова (или другое лекарство/аптеку).
8. Бонус «Uy dorixonasi»: вкладка «Dorixona» → карточка «Uy dorixonasi» → у Smekta «Muddati o‘tgan» →
   «Buyurtma berish» → поиск аптеки с готовым запросом.

*Вариант B — с Supabase (realtime):* нужен вход в аккаунт, применённые seed-миграции и интернет.
1. `flutter run --release --dart-define-from-file=env.json`, войти, забронировать Paracetamol, остаться на вкладке.
2. В Supabase Dashboard → SQL Editor (за кулисами):
   ```sql
   update public.reservations set status = 'ready'
   where status = 'pending' and created_at > now() - interval '10 minutes';
   ```
3. Realtime доставит изменение за ~1 с → баннер, конфетти, вибрация, шаги «Tayyor».
