# Фича `onboarding`

**Владелец:** модуль A (лид)

## Что делает
Приветствие, выбор языка, регистрация/вход (Supabase Auth), первичная анкета профиля (возраст, рост, вес, группа крови, аллергии). В fake-режиме «Boshlash» ставит флаг сессии в prefs.

## Маршруты
- `/onboarding` (`AppRoutes.onboarding`) — полноэкранный; редирект сюда, если нет сессии

## Home-карточки
— нет

## Таблицы БД
`profiles` (заполнение после регистрации)

## Файлы
- `onboarding_feature.dart` — единственный публичный файл (`onboardingRoutes`, `onboardingHomeCards`)
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- Тесты: `test/features/onboarding/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [ ]
