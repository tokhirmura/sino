# Фича `family`

**Владелец:** модуль A (лид)

## Что делает
«Oila» — забота о семье: что сегодня с лекарствами, приёмами и бронями у каждого члена семьи.

- **`/family`** (`presentation/family_screen.dart`) — `AppScaffold` «Oila», в подзаголовке «3 kishidan 2 nafari dorini ichdi».
  На каждого из `family_members` (core `familyMembersProvider`) — карточка:
  - emoji по родству, имя, «Ona · 56 yosh», кольцо «принято X / Y» (зелёное, при пропуске — гранат), ✏️ → форма в профиле;
  - дозы сегодня: ✅ принято · ❌ пропущено · 🕒 ещё не время;
  - **пропуск** — доза не отмечена через **30 минут** после времени (`missedAfter`): красный блок «Onam dorini ichmadi»
    (родство → «Onam / Otam / Qizim…», в ru/en — нейтрально) и кнопка «Qoʻngʻiroq qilish» (`tel:` через
    `url_launcher`, `dialerProvider`); телефона нет — «Telefon raqamini qo‘shish» → форма;
  - ближайший приём к врачу (`appointments` booked, в будущем) и активная бронь (`reservations` pending/ready).
  - внизу честный блок «Kelajakda»: сейчас родственники — профили внутри одного аккаунта (дозы отмечаете вы);
    дальше — приглашение по ссылке и уведомления родным. Дисклеймер.
  - нет семьи — `EmptyState` «Oila a’zolarini qo‘shing» → форма.
- **Карточка на главной** (`presentation/family_home_card.dart`, id `family`, order 85): сводка и красные строки
  «⚠️ Onam dorini ichmadi»; нет семьи — приглашение добавить. Для цели «Oila salomatligi» главная ставит её сразу
  после SOS (`home/application/goal_order.dart`).

Обновление: данные перечитываются при каждом открытии `/family` (дозы отмечают в «Eslatmalar» — фича B), при изменении
семьи и pull-to-refresh.

## Данные
`data/family_care_repository.dart` — `FamilyCareRepository.load(now)`; только select своих строк, код коллег не импортируется:
- `reminders` с `member_id` (+ `created_at` — до создания доз нет), сегодняшние `reminder_logs`,
- `appointments` (booked, будущие, `doctors(name, specialty)`), `reservations` (pending/ready, `medicines(name)`,
  `pharmacies(name)`).

Fake — `assets/core/family_care.json` (члены — core `FamilyMember.fakes`): маме Dilfuza 2 лекарства, второе пропущено
(время задано «N минут назад», поэтому пропуск виден в любое время демо), папе — Amlodipin и онлайн-приём, дочке —
Nurofen в 20:00, маме — готовая бронь. У мамы и папы есть телефоны.

Демо в Supabase — профиль → режим разработчика → «Namuna ma’lumotlarni yuklash» (`profile/data/sample_data_repository.dart`):
маме 2 напоминания (одно отмечено), папе приём, маме бронь; только пока у семьи нет напоминаний.

`application/family_care.dart` — без Flutter: `CareDose.missedAt`, `MemberCare` (taken/total, `onTrackAt`),
`buildFamilyCare`, `summarizeFamily` → `FamilySummary`; провайдеры `familyCareRawProvider`, `familyCareProvider`,
`familySummaryProvider`, `familyClockProvider` (тесты), `dialerProvider` (тесты).

## Маршруты
- `/family` (`AppRoutes.family`) — полноэкранный

## Home-карточки
- `family`, order 85 — «Oila»

## Таблицы БД
Чтение своих строк: `reminders`, `reminder_logs`, `appointments` (+ `doctors`), `reservations` (+ `medicines`,
`pharmacies`); члены семьи и `family_members.phone` — через core.

## Файлы
- `family_feature.dart` — единственный публичный файл (`familyRoutes`, `familyHomeCards`)
- Тесты: `test/features/family/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] «Oila»: экран `/family` (дозы X из Y, приём, бронь), пропуск через 30 мин — красная метка и звонок,
  `family_members.phone` (миграция `20261121160000_core_family_phone.sql`, поле в форме), карточка на главной,
  демо (fake и «Namuna ma’lumotlar»), блок «Kelajakda»
