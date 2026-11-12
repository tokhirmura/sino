# Фича `profile`

**Владелец:** модуль A (лид)

## Что делает
Профиль пользователя, члены семьи, медкарта (записи из davlat/xususiy учреждений), анализы, QR-медкарта (`qr_flutter`), язык, выход.

Режим разработчика: 7 нажатий на строку «Sino · v1.0.0» внизу профиля (флаг `profile.dev_mode`, повтор — выключить).
В нём карточка «Namuna ma’lumotlarni yuklash» (`SampleDataRepository`): добавляет текущему пользователю семью (3),
медкарту (8) и анализы (7) из `assets/core/sample_profile_data.json`. Только в пустой аккаунт — если есть хоть
одна запись в `family_members` / `medical_records` / `lab_results`, ничего не добавляет. В fake-режиме данные и так есть.

## Маршруты
- `/profile` (`AppRoutes.profile`) — вкладка «Profil»

## Home-карточки
— нет

## Таблицы БД
`profiles`, `family_members`, `medical_records`, `lab_results`

## Файлы
- `profile_feature.dart` — единственный публичный файл (`profileRoutes`, `profileHomeCards`)
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- Тесты: `test/features/profile/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] P0-3 Скрытая кнопка «Namuna ma’lumotlarni yuklash» (только режим разработчика): засевает семью,
  медкарту и анализы текущему пользователю — для показа жюри
- [ ] P1-5 Профиль и семья из БД: добавить / изменить / удалить члена семьи
- [ ] P1-5 Электронная медкарта: лента `medical_records` с меткой davlat/xususiy
- [ ] P1-5 Анализы `lab_results` со шкалой нормы
- [ ] P1-5 QR для врача (`qr_flutter`) с выбором, что видно
- [ ] P1-5 Настройки: язык uz/ru/en (сохраняется в `profiles.lang`), тёмная тема, выход из аккаунта
- [ ] P1-6 Тёмная тема и uz/ru/en
