# Фича `doctors`

**Владелец:** модуль B

## Что делает
Каталог врачей (специальность, стаж, рейтинг, цена, клиника, онлайн), запись на приём для себя или члена семьи, список записей.

## Маршруты
- `/doctors` (`AppRoutes.doctors`) — полноэкранный

## Home-карточки
- `doctors`, order 80

## Таблицы БД
`doctors`, `appointments`

## Файлы
- `doctors_feature.dart` — единственный публичный файл (`doctorsRoutes`, `doctorsHomeCards`)
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- Тесты: `test/features/doctors/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [ ]
