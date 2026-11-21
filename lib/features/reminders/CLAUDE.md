# Фича `reminders`

**Владелец:** модуль B

## Что делает
Напоминания о приёме лекарств (для себя и членов семьи) через `flutter_local_notifications` + `timezone`, отметка «принял», история приёма.

## Решения по схеме
- **Одна строка `reminders` = одно время в день.** «3 раза в день» — три строки. `time` — локальное время
  устройства (`HH:mm:ss`), `days` — 1 = Пн … 7 = Вс, хранится отсортированным без повторов
  (`Reminder.normalizeDays`); пустой список сохранить нельзя.
- **Лог ↔ доза:** в `reminder_logs` нет колонки «какая доза», поэтому лог относится к дозе того же
  `reminder_id` в ту же **локальную дату** `taken_at`. Не больше одного лога на напоминание в день
  (`markTaken` повторно возвращает существующий). Отметка за прошлый день пишет `taken_at` = время по
  расписанию. Ограничение: доза 23:30, принятая после полуночи, засчитается следующему дню.
- **Статус дозы** (`Dose.status(now)`): `taken` (есть лог) → `upcoming` (до времени) → `due` (в течение
  `doseGrace` = 2 ч) → `missed`. Принятая доза видна в дне, даже если напоминание потом поставили на паузу.
- **Соблюдение** (`adherence`, 7 дней): в знаменатель идут принятые и пропущенные дозы; сегодняшние будущие и
  дозы до создания напоминания (`created_at`) не считаются.
- Удаление напоминания удаляет и его историю (`on delete cascade`; Fake делает то же).
- История грузится за последние 30 дней (`reminderHistoryDays`).

## Уведомления
- `data/reminder_notifications.dart`: `LocalReminderNotifications` пересоздаёт все наши уведомления после
  каждого подтверждённого изменения и при загрузке (`RemindersNotifier._sync`). Свои отличаем по payload
  `reminder:<id>` — чужие уведомления не трогаем. id — FNV-1a от `reminder.id` × 10 + день недели (0 — каждый
  день), стабильны между запусками.
- Каждый день → одно повторяющееся уведомление (`DateTimeComponents.time`), иначе по одному на день недели
  (`dayOfWeekAndTime`) — укладываемся в лимит iOS 64.
- `AndroidScheduleMode.inexactAllowWhileIdle` — без разрешения на точные будильники, допуск в несколько минут.
- Часовой пояс: имя зоны устройства из `flutter_timezone` (`LocalReminderNotifications.deviceLocation`); если
  плагин недоступен или имени нет в базе tz — любая зона с текущим смещением устройства, иначе UTC.
- Текст — на языке приложения (`appLangProvider`), с именем члена семьи из `familyMembersProvider`.
- Всё best effort: ошибки плагина (нет разрешения, не настроен натив, тесты) глотаются — напоминания в приложении
  работают и без уведомлений. Разрешение спрашивает UI: `ref.read(reminderNotificationsProvider).requestPermission()`.

## Экраны
- **Design 2.0:** `/reminders` — `GradientHeader` (назад, история, `StatTile` «Bugun ichildi» / «Faol»),
  `SkeletonLoader`, `EmptyState(actionLabel:)`, каскад карточек (`presentation/motion.dart`, `DoseTile(index:)`),
  «Saqlash» — `PrimaryButton`.
- **`/reminders`**: карточка «соблюдение за 7 дней» + следующая доза → история; «Bugun» — дозы сегодня по времени
  (статус, член семьи, «Ichdim» / отмена — `markTaken` / `undo`); «Barcha eslatmalar» — все напоминания с
  переключателем паузы, тап → изменить; FAB «Qo‘shish». Пусто → `EmptyState` с кнопкой.
- **Форма** (`/reminders/new`, `/reminders/:id`): название (обязательно), доза, время (`showTimePicker`, 24 ч),
  дни недели + пресеты (каждый день / будни / выходные), для себя / члена семьи; в режиме изменения — «O‘chirish»
  с подтверждением (форма сначала закрывается: оптимистичное удаление её размонтирует).
- **Разрешение на уведомления** — один раз, после первого сохранённого напоминания (prefs
  `reminders.permission_asked`).
- **История** (`/reminders/history`): 14 дней, по дням дозы из `dosesForDayProvider(day)` — лог к дозе по
  `reminder_id` + локальной дате `taken_at`: «Ichildi · 08:04 da» или «O‘tkazib yuborildi» (пропущенную можно
  отметить задним числом — `taken_at` = время по расписанию); счёт дня «2 / 3», процент за 7 дней. Дозы до
  `created_at` напоминания не показываются.
- **Home-карточка**: «Hozir: …» (доза в окне `doseGrace`, цвет coral) / «Keyingi: 20:00 · …» / «ertaga …».
- Узкие карточки: свой `Tag` (как core `Pill`, но с многоточием) — `Pill` не сжимается и переполняет строку.
- Fake: демо пишется один раз (`_seeding` — общий future): на первом запуске `reminders()` и `logsSince()` идут
  параллельно, без этого одно чтение видело только половину демо (`null` → ошибка home-карточки).
- `DoseTile`: в узкой карточке (< 300) кнопка «Ichdim» уходит под теги.

## Маршруты
- `/reminders` (`AppRoutes.reminders`) — полноэкранный
- Подэкраны (`presentation/reminders_paths.dart`): `/reminders/new`, `/reminders/history`, `/reminders/:id`
  (фиксированные пути объявлены раньше `:id`)

## Home-карточки
- `reminders`, order 30

## Таблицы БД
`reminders`, `reminder_logs`

## Файлы
- `reminders_feature.dart` — единственный публичный файл (`remindersRoutes`, `remindersHomeCards`)
- `data/models.dart` — `Reminder`, `ReminderLog`, `Dose`, `DoseStatus`, `doseGrace`
- `data/reminders_repository.dart` — `RemindersRepository` + Supabase + Fake (демо из `assets/pharmacy/fake_pharmacy.json`)
- `data/reminder_notifications.dart` — `ReminderNotifications` (Local / Noop), `reminderNotificationId`,
  `reminderNotificationText`
- `application/reminder_schedule.dart` — чистые правила: `dosesForDay`, `nextDose`, `adherence`, `logFor`
- `application/reminders_providers.dart` — `remindersProvider` (`RemindersNotifier`: оптимистичные `add` / `edit` /
  `setActive` / `remove`, откат и rethrow, проверки — `ReminderException`), `reminderLogsProvider`
  (`ReminderLogsNotifier`: `markTaken(reminder, day)` / `undo(logId)`), `dosesForDayProvider(day)`,
  `nextDoseProvider`, `adherenceProvider`, `intakeHistoryProvider`
- `application/write_queue.dart` — очередь записей и `pending-…` id
- `presentation/` — `reminders_screen.dart`, `reminder_form_screen.dart`, `history_screen.dart`, `labels.dart`
  (дни недели, «Har kuni / Ish kunlari», статусы доз), `widgets.dart` (`DoseTile`, `RemindersDisclaimer`, `Tag`,
  тексты ошибок)
- Тесты: `test/features/reminders/` — `reminders_screens_test.dart`: отметка/отмена дозы, пауза, добавление (с
  валидацией, для члена семьи, разрешение один раз), изменение и удаление, история, home-карточка, каждый экран
  + home-карточка в uz/ru/en × светлая/тёмная на 320×568 с шрифтом ×1.3. После `enterText` снимайте фокус перед прокруткой — иначе поле
  прокручивает каретку обратно. Уведомления подменяются записывающим фейком через
  `reminderNotificationsProvider.overrideWithValue`.
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Нужно от лида
- `supabase db push` для `supabase/migrations/20261117120000_pharmacy_seed.sql` (общая seed-миграция модуля B).

## Чеклист задач
- [x] Данные: модели, репозиторий (Supabase + Fake), правила расписания и соблюдения, сервис уведомлений,
  провайдеры, тесты
- [x] `/reminders`: сегодня по времени (принял / отменить), добавить и изменить (для себя / члена семьи, дни,
  время, доза), пауза, удаление
- [x] История приёма и соблюдение за 7 дней
- [x] Запрос разрешения на уведомления при первом напоминании
- [x] `remindersHomeCards`: следующая доза
- [x] Тёмная тема и uz/ru/en (3 языка × 2 темы, 320×568 и шрифт ×1.3 в тестах)

**Sprint 2.0 B+**
- [x] Часовой пояс устройства через `flutter_timezone` (обход `Asia/Tashkent` убран)
- [x] Гонка демо-данных на первом запуске (ошибка home-карточки «Bugun»)
- [x] Контраст и переполнение (светлая/тёмная, 320×568, шрифт ×1.3)
- [x] Design 2.0: `GradientHeader` + `StatTile`, `SkeletonLoader`, `EmptyState` с действием, `PrimaryButton`, каскад
- Не успели: —

## Для лида (Sprint 2.0 B+, ветка `feat/module-b-v2`)

**Сделано:** см. «Чеклист задач → Sprint 2.0 B+». Новых миграций нет.

**Известные ограничения**
- Уведомления неточные (`inexactAllowWhileIdle`, допуск несколько минут) — разрешение на точные будильники не
  запрашиваем. На iOS — лимит 64 запланированных уведомления (укладываемся: одно на ежедневное напоминание).
- Доза 23:30, отмеченная после полуночи, засчитается следующему дню (в `reminder_logs` нет ссылки на дозу).
- Нет плагина часового пояса / неизвестная зона → зона с тем же смещением, иначе UTC.

**Демо жюри**
- Fake-режим (`--dart-define=USE_FAKE=true`, чистые данные) уже содержит 4 напоминания (Amlodipin для отца,
  Vitamin D3, Omeprazol на паузе, Nurofen для дочери) и историю. Главная → карточка напоминаний → `/reminders`, раздел «Bugun» → «Ichdim» у дозы →
  счётчик «Bugun ichildi» в шапке растёт; «Qabul tarixi» — соблюдение за 7 дней.
- Чтобы показать уведомление: «Qo‘shish» → время на 1–2 минуты вперёд → «Saqlash» → разрешить уведомления
  (учтите допуск неточного расписания).
