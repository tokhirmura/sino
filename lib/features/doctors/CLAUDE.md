# Фича `doctors`

**Владелец:** модуль B

## Что делает
Каталог врачей (специальность, стаж, рейтинг, цена, клиника, онлайн), запись на приём для себя или члена семьи, список записей.

Каталог — `assets/pharmacy/doctors.json` (id `a4000000-…`), seed — общий для модуля B, см.
`lib/features/pharmacy/CLAUDE.md`. Демо-записи — `assets/pharmacy/fake_pharmacy.json` (`days_from_now`).

## Решения по схеме
- **`doctors.specialty`** — слаг на узбекской латинице (как `family_members.relation`), список —
  `doctorSpecialties`: `terapevt, pediatr, kardiolog, nevrolog, dermatolog, ginekolog, lor, oftalmolog, stomatolog,
  endokrinolog, gastroenterolog, psixolog`. Подписи uz/ru/en — в `presentation/`. Неизвестный слаг из БД не
  ломает приложение: показывается как есть, в фильтре — в конце.
- **`price_uzs = 0`** — бесплатно (государственная поликлиника), `Doctor.isFree`.
- **Слоты генерируются на устройстве** (таблицы расписания нет): Пн–Сб, 09:00–17:00, обед 13:00–14:00, по 30 мин,
  запись на 14 дней вперёд (`doctor_slots.dart`). Чужие записи скрыты RLS, поэтому занятость врача имитируется:
  ~30 % слотов `busy` по хэшу (врач + время) — одинаково на всех устройствах.
- Состояния слота: `free`, `past`, `busy`, `mine` (своя запись к этому врачу), `clash` (у этого же человека
  в это время запись к другому врачу; член семьи считается отдельно).
- **Онлайн** — только у врачей с `online = true` (`AppointmentProblem.onlineNotSupported`).
- **Статусы:** `booked → done` ставит клиника; пользователь только отменяет `booked → cancelled`.
  Прошедшая `booked` показывается как прошедшая (`isPast`), статус не меняем.
- Ограничение: на сервере нет `unique (doctor_id, starts_at)`, два разных пользователя могут занять один слот.
  Если понадобится — лиду миграция с частичным уникальным индексом `where status = 'booked'`.

## Экраны
- **`/doctors`**: поиск (имя, специальность, клиника), чипы «Onlayn» и специальностей (подписи uz/ru/en —
  `presentation/labels.dart`: `specialtyLabel`, `specialtyEmoji`, `specialtyColor`), счётчик, карточки врачей
  (стаж, рейтинг, онлайн, цена / «Bepul»); баннер ближайшей записи; в app bar — «Mening yozuvlarim» с бейджем.
- **Врач** (`/doctors/:id`): шапка, дисклеймер, «Kim uchun» (я / `familyMembersProvider`), «Qabul turi» (только
  у `online`-врачей), дни (`bookingDays`; сегодня — только если остались слоты, иначе завтра), сетка слотов из
  `doctorSlotsProvider`: свободные — выбор, `busy`/`clash` зачёркнуты, `mine` — ✓, прошедшие скрыты; кнопка
  «Yozilish · Ertaga · 10:30» → `book`, snackbar с переходом к записям. Ошибка (`slotUnavailable` и др.) —
  понятный текст, выбор сбрасывается.
- **«Mening yozuvlarim»** (`/doctors/appointments`): «Kelgusi» и «O‘tgan va bekor qilingan» — статус, очно/онлайн,
  член семьи, клиника; отмена предстоящей с подтверждением. Тап → врач.
- **Home-карточка**: «Ertaga · 10:30 · Terapevt» → записи, иначе «Qabulga yozilish» → каталог.
- Свой `Tag` вместо core `Pill` в узких карточках (см. reminders).

## Маршруты
- `/doctors` (`AppRoutes.doctors`) — полноэкранный
- Подэкраны (`presentation/doctors_paths.dart`): `/doctors/appointments`, `/doctors/:id` (`appointments` — раньше `:id`)

## Home-карточки
- `doctors`, order 80

## Таблицы БД
`doctors`, `appointments`

## Файлы
- `doctors_feature.dart` — единственный публичный файл (`doctorsRoutes`, `doctorsHomeCards`)
- `data/models.dart` — `Doctor`, `Appointment` (join `doctors(*)`), `AppointmentStatus`, `doctorSpecialties`
- `data/doctors_repository.dart` — `DoctorsRepository` + Supabase + Fake, `filterDoctors` (специальность, текст, онлайн)
- `application/doctor_slots.dart` — `bookingDays`, `daySlotTimes`, `isBusySlot`, `slotsFor`, `SlotState`
- `application/doctors_providers.dart` — `doctorsCatalogProvider`, `doctorsByIdProvider`, `specialtiesProvider`,
  `appointmentsProvider` (`AppointmentsNotifier`: оптимистичные `book(doctor, at, memberId:, online:)` /
  `cancel(id)`, слот перепроверяется перед записью, ошибки — `AppointmentException`),
  `upcomingAppointmentsProvider`, `pastAppointmentsProvider`, `doctorSlotsProvider((doctorId:, day:, memberId:))`
- `application/write_queue.dart` — очередь записей и `pending-…` id
- `presentation/` — `doctors_screen.dart`, `doctor_screen.dart`, `appointments_screen.dart`, `labels.dart`,
  `widgets.dart` (`DoctorTile`, `AppointmentCard`, `DoctorPrice`, `DoctorsDisclaimer`, `Tag`, тексты ошибок)
- Тесты: `test/features/doctors/` — `doctors_screens_test.dart`: фильтры и переводы, поиск + онлайн, запись для
  члена семьи и онлайн, записи и отмена, home-карточка, каждый экран в uz/ru/en × светлая/тёмная на 360×640
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Нужно от лида
- `supabase db push` для `supabase/migrations/20261117120000_pharmacy_seed.sql` (в ней каталог `doctors`).

## Чеклист задач
- [x] Данные: каталог (16 врачей, 12 специальностей), модели, репозиторий (Supabase + Fake), генерация слотов,
  провайдеры, тесты
- [x] `/doctors`: каталог с фильтром по специальности, поиском и «онлайн»
- [x] Карточка врача → выбор дня и слота, для себя / члена семьи, очно / онлайн → запись
- [x] «Mening yozuvlarim»: предстоящие и прошедшие, отмена
- [x] `doctorsHomeCards`: ближайшая запись
- [x] Тёмная тема и uz/ru/en (3 языка × 2 темы, 360×640 в тестах)
