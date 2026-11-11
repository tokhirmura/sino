# Фича `profile`

**Владелец:** модуль A (лид)

## Что делает
Профиль пользователя, члены семьи, медкарта (записи из davlat/xususiy учреждений), анализы, QR-медкарта (`qr_flutter`), язык, выход.

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
- [ ] P0-3 Скрытая кнопка «Namuna ma’lumotlarni yuklash» (только режим разработчика): засевает семью,
  медкарту и анализы текущему пользователю — для показа жюри
- [ ] P1-5 Профиль и семья из БД: добавить / изменить / удалить члена семьи
- [ ] P1-5 Электронная медкарта: лента `medical_records` с меткой davlat/xususiy
- [ ] P1-5 Анализы `lab_results` со шкалой нормы
- [ ] P1-5 QR для врача (`qr_flutter`) с выбором, что видно
- [ ] P1-5 Настройки: язык uz/ru/en (сохраняется в `profiles.lang`), тёмная тема, выход из аккаунта
- [ ] P1-6 Тёмная тема и uz/ru/en
