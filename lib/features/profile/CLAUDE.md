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
- [ ]
