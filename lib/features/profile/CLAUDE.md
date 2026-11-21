# Фича `profile`

**Владелец:** модуль A (лид)

## Что делает
Вкладка «Profil» сверху вниз:
- **Карточка пользователя** (имя, возраст, рост, вес, группа крови, аллергии) → тап — редактирование `profiles`
  (там же «Asosiy maqsad» — core `GoalPicker`, меняет порядок карточек на главной).
- **Yutuqlar:** карточка «Yutuqlar N / 8» с полоской всех значков → `/profile/achievements`
  (`presentation/achievements_screen.dart`): кольцо прогресса, 8 `AchievementBadge` (открытые — сверху, новые первыми,
  с датой; закрытые — серые), тап → лист «как получить». Данные — core `achievementsProvider`; открывает значки home.
- **Tibbiy karta:** электронная медкарта (лента `medical_records`, новые сверху, метка Davlat/Xususiy, фильтр
  «Hammasi / Men / член семьи»), анализы (`lab_results` со шкалой нормы и сводкой «N из M вне нормы»),
  QR для врача.
- **QR для врача:** пользователь включает, что видно (имя/возраст/рост/вес, группа крови, аллергии, диагнозы,
  рецепты, анализы). В QR — обычный текст: читается любой камерой, без приложения и интернета. Только свои записи,
  не семьи; до 5 пунктов в списке.
- **Oila:** список `family_members`; «Qo‘shish» → форма; тап → изменить / удалить (с подтверждением; записи
  медкарты этого человека удаляются каскадом). `relation` хранится по-узбекски (`ona`, `ota`, `qizi`, …),
  подписи — `presentation/labels.dart`.
- **Sozlamalar:** язык (сразу в приложении + `profiles.lang`; если сохранить в БД не вышло — только на устройстве),
  тема (система / светлая / тёмная, core `themeModeProvider`), выход.

Fake-режим: медкарта и анализы — из `assets/core/sample_profile_data.json` (даты относительно сегодня), семья —
core `fakeFamilyProvider` (изменения сохраняются в prefs).

Режим разработчика: 7 нажатий на строку «Sino · v1.0.0» внизу профиля (флаг `profile.dev_mode`, повтор — выключить).
В нём карточка «Namuna ma’lumotlarni yuklash» (`SampleDataRepository`): добавляет текущему пользователю семью (3),
медкарту (8) и анализы (7) из `assets/core/sample_profile_data.json`. Только в пустой аккаунт — если есть хоть
одна запись в `family_members` / `medical_records` / `lab_results`, ничего не добавляет. В fake-режиме данные и так есть.

## Маршруты
- `/profile` (`AppRoutes.profile`) — вкладка «Profil»
- подэкраны поверх NavigationBar (`presentation/profile_paths.dart`): `/profile/edit`, `/profile/records`,
  `/profile/labs`, `/profile/qr`, `/profile/family/new`, `/profile/family/:id`
- `/profile/achievements` (`AppRoutes.achievements` — открывается и с главной)

## Home-карточки
— нет

## Таблицы БД
`profiles`, `family_members`, `medical_records`, `lab_results`, `achievements` (чтение, через core)

## Файлы
- `profile_feature.dart` — единственный публичный файл (`profileRoutes`, `profileHomeCards`)
- `data/medical_repository.dart` — `MedicalRecord`, `LabResult`, `medicalRecordsProvider`, `labResultsProvider`
- `data/family_repository.dart` — добавить / изменить / удалить члена семьи (чтение — core `familyMembersProvider`)
- `application/doctor_qr.dart` — текст QR (`buildDoctorQrText`) и выбранные поля
- Тесты: `test/features/profile/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] P0-3 Скрытая кнопка «Namuna ma’lumotlarni yuklash» (только режим разработчика): засевает семью,
  медкарту и анализы текущему пользователю — для показа жюри
- [x] P1-5 Профиль и семья из БД: добавить / изменить / удалить члена семьи
- [x] P1-5 Электронная медкарта: лента `medical_records` с меткой davlat/xususiy
- [x] P1-5 Анализы `lab_results` со шкалой нормы
- [x] P1-5 QR для врача (`qr_flutter`) с выбором, что видно
- [x] P1-5 Настройки: язык uz/ru/en (сохраняется в `profiles.lang`), тёмная тема, выход из аккаунта
- [x] P1-6 Тёмная тема и uz/ru/en (проверяет `test/module_a_screens_test.dart`: 3 языка × 2 темы, 360×640)

## Спринт 2.0 (план — в `home/CLAUDE.md`)
- [x] S2-3 Экран достижений в профиле: 8 значков `AchievementBadge`, новое — с confetti; таблица `achievements`
