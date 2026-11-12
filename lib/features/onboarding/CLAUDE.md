# Фича `onboarding`

**Владелец:** модуль A (лид)

## Что делает
Приветствие, выбор языка, регистрация/вход (Supabase Auth), первичная анкета профиля (возраст, рост, вес, группа крови, аллергии).

Поток (всё внутри одного маршрута `/onboarding`, шаги переключает `OnboardingScreen`):
3 слайда (показываются один раз, флаг `onboarding.intro_seen`) → выбор входа: OneID / email / гость.
Без сессии роутер редиректит любой путь на `/onboarding`, а при появлении сессии сам уводит на главную,
поэтому шаги **не навигируют** после успеха, а у OneID сессия создаётся только после согласия.
В fake-режиме все три пути ставят флаг `fakeAuthProvider`.

Для реального Supabase в Dashboard → Authentication → Providers должен быть включён **Anonymous sign-ins**
(гость и OneID), иначе пользователь увидит «этот способ входа отключён».

## Маршруты
- `/onboarding` (`AppRoutes.onboarding`) — полноэкранный; редирект сюда, если нет сессии

## Home-карточки
— нет

## Таблицы БД
`profiles` (заполнение после регистрации)

## Файлы
- `onboarding_feature.dart` — единственный публичный файл (`onboardingRoutes`, `onboardingHomeCards`)
- `presentation/` — экраны, `application/` — провайдеры, `data/` — репозиторий (abstract + Supabase + Fake)
- `data/auth_repository.dart` — `AuthRepository` (аноним, email вход/регистрация) + Supabase + Fake
- `data/one_id_provider.dart` — `OneIdAuthProvider`: **единственное место**, которое знает про OneID
  (сейчас мок биометрии ~2 с + `assets/core/oneid_mock.json` + анонимная сессия). Настоящий OneID — менять только его
- `application/auth_errors.dart` — `AuthErrorKind` из исключений Supabase; тексты uz/ru/en — `presentation/auth_error_text.dart`
- Тесты: `test/features/onboarding/`
- Общие правила — в корневом `CLAUDE.md`. Чужие папки, `lib/core`, `lib/app` не трогать.

## Чеклист задач
- [x] P0-2 Онбординг: 3 слайда о приложении → экран входа с тремя путями
  - [x] «OneID orqali kirish»: биометрия ~2 с → «Profil davlat tomonidan tasdiqlangan» + подтянутые данные
    (поликлиника, медкарта, рецепты, страховка) → согласие на доступ к медкарте. Пока OneID не провайдер Auth —
    настоящая анонимная сессия Supabase; провайдер изолирован в одном классе. Логотип OneID не используем — только текст
  - [x] «Email orqali kirish»: регистрация и вход по email + паролю (Supabase Auth)
  - [x] «Mehmon sifatida davom etish»: анонимный вход
  - [x] Ошибки входа — понятный текст uz/ru/en; в fake-режиме все три пути ставят флаг входа
- [ ] P0-3 Первый вход: пустой профиль → анкета (имя, год рождения, рост, вес) → `profiles`
- [ ] P1-6 Все экраны в тёмной теме и на uz/ru/en
