# Sino

Одно приложение для здоровой жизни: аптеки и лекарства, питание, тренировки, погода и воздух, врачи, медкарта.
Хакатон Smart Healthcare (Узбекистан). Flutter + Supabase.

Правила работы и архитектура — в [CLAUDE.md](CLAUDE.md) (обязательно к прочтению).

## Требования
- **Flutter 3.47.9** (stable, Dart 3.13.7) — `flutter --version`
- Android Studio + эмулятор (API 24+), для iOS — Xcode (iOS 15+)
- Node.js (для Supabase CLI через `npx supabase …`) — нужен только лиду

## Запуск

### С Supabase
1. Скопируйте `env.example.json` → `env.json` и заполните (значения даёт лид, **не коммитить**):
   ```json
   { "SUPABASE_URL": "https://xxxx.supabase.co", "SUPABASE_ANON_KEY": "…", "USE_FAKE": "false" }
   ```
2. `flutter pub get`
3. `flutter run --dart-define-from-file=env.json`

### Без ключей (fake-режим, офлайн)
```bash
flutter run                                  # ключей нет → fake
flutter run --dart-define=USE_FAKE=true      # принудительно fake даже с ключами
```
В fake-режиме Supabase не инициализируется, данные берутся из `assets/<модуль>/*.json`,
«сессия» — флаг в SharedPreferences (кнопка «Boshlash» на онбординге).

### Проверки перед коммитом
```bash
dart format lib test
flutter analyze
flutter test
```

## Процесс

### Ветки
- `main` — защищённая, только через PR с зелёным CI.
- Ветка на задачу: `feat/<фича>-<кратко>` (например `feat/pharmacy-search`), `fix/<фича>-…`.
- Часто делайте `git pull --rebase origin main`, PR — небольшие, несколько раз в день.

### Pull request
- Шаблон заполняется автоматически (`.github/pull_request_template.md`): что сделано, скриншот,
  проверено на Android/iOS, есть ли миграция, чужие папки не тронуты.
- CI (`.github/workflows/ci.yml`): format → analyze → test.
- CODEOWNERS назначает ревьюера: изменения вне своих папок требуют одобрения лида.
- Коммиты: `feat(pharmacy): поиск по штрих-коду`, `fix(nutrition): …`, `chore(core): …`.

### Миграции БД
- Схема меняется **только новой миграцией**:
  `supabase/migrations/<YYYYMMDDHHMMSS>_<core|pharmacy|wellness>_<что>.sql`
  (например `20261112093000_pharmacy_add_medicine_photo.sql`). Можно создать: `npx supabase migration new pharmacy_add_medicine_photo`.
- У новых таблиц обязательно RLS, политики и GRANT для anon/authenticated (см. CLAUDE.md, п.4).
- Уже применённые миграции **не редактировать**.
- `supabase db push` запускает **только лид** после мержа PR.

## Структура
```
lib/app/        роутер, реестр фич, shell (лид)
lib/core/       тема, l10n, виджеты, backend, контракты (лид)
lib/features/   12 фич: модуль A — onboarding, home, profile, sos, assistant;
                модуль B — pharmacy, reminders, doctors; модуль C — nutrition, workouts, vitals, weather
assets/         core/, pharmacy/, wellness/ — fake-данные по модулям
tool/           pharmacy/, wellness/ — скрипты подготовки данных
supabase/       config.toml, migrations/
test/           smoke-тест + test/features/<x>/
```
