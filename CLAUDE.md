# Sino — CLAUDE.md

Sino — одно приложение для здоровой жизни (хакатон Smart Healthcare, Узбекистан): аптеки и лекарства,
питание, тренировки, погода и воздух, врачи, медкарта. 3 разработчика × 4 дня в одном репозитории,
параллельно. **Каждый пишет только в папках своих фич.**

## Стек
- Flutter 3.47.9 (Dart 3.13), Material 3, Android + iOS
- Состояние: `flutter_riverpod` 3 **без codegen** (`Provider`, `FutureProvider`, `StreamProvider`, `Notifier`)
- Навигация: `go_router` (`StatefulShellRoute.indexedStack`, 5 вкладок)
- Бэкенд: Supabase (`supabase_flutter`), схема в `supabase/migrations/`
- Ещё: shared_preferences, http, flutter_map + latlong2, geolocator, mobile_scanner, image_picker,
  fl_chart, flutter_local_notifications + timezone, intl, url_launcher, qr_flutter
- **Без** build_runner / freezed / json_serializable — модели пишем руками (`fromMap`).

## Модули и владельцы
| Модуль | Фичи (`lib/features/…`) | Ассеты / утилиты |
|---|---|---|
| A (лид) | onboarding, home, profile, sos, assistant | `assets/core/` |
| B | pharmacy, reminders, doctors | `assets/pharmacy/`, `tool/pharmacy/` |
| C | nutrition, workouts, vitals, weather | `assets/wellness/`, `tool/wellness/` |

## Структура
```
lib/
  main.dart                 # prefs + Backend.init + ProviderScope
  app/                      # ТОЛЬКО ЛИД
    app.dart                # SinoApp (MaterialApp.router), appOverrides()
    router.dart             # GoRouter: shell (5 вкладок) + полноэкранные маршруты, redirect
    feature_registry.dart   # импорт всех <x>_feature.dart → tabBranchRoutes, fullscreenRoutes, allHomeCards
    shell_scaffold.dart     # NavigationBar
  core/                     # ТОЛЬКО ЛИД — общее для всех
    backend/backend.dart    # Backend.init, useFakeProvider, supabaseClientProvider, authStateProvider, isSignedInProvider
    contracts/home_card.dart# HomeCardSpec, homeCardsProvider
    data/user.dart          # currentUserProvider, familyMembersProvider (+ fake-данные),
                            # profileRepositoryProvider (сохранить profiles), profileGateProvider (анкета),
                            # fakeProfileProvider (fake-профиль в prefs; по умолчанию «Aziz, 29»),
                            # fakeFamilyProvider (fake-семья в prefs; меняет фича profile)
    l10n/app_lang.dart      # AppLang, appLangProvider, context.tr(uz:, ru:, en:), context.trMap(json)
    routing/app_routes.dart # AppRoutes.* (пути, в т.ч. profileSetup), rootNavigatorKey
    storage/prefs.dart      # sharedPreferencesProvider
    theme/                  # AppColors, AppTheme (светлая/тёмная), AppSpacing, AppShadows,
                            # themeModeProvider (выбор в профиле)
    widgets/                # AppScaffold, AppCard, ShortcutCard, SectionTitle, Pill, EmojiBox,
                            # ProgressRing, EmptyState, ErrorView (+ errorMessage), LoadingView,
                            # Skeleton/SkeletonList, AsyncValueView, Money/formatMoney
  features/<x>/
    <x>_feature.dart        # ЕДИНСТВЕННЫЙ публичный файл: <x>Routes, <x>HomeCards
    presentation/           # экраны и виджеты
    application/            # провайдеры / нотифаеры
    data/                   # репозиторий: abstract + Supabase + Fake
    CLAUDE.md               # владелец, что делает, маршруты, таблицы, чеклист
```

## Контракт фичи
- `lib/features/<x>/<x>_feature.dart` экспортирует только `final List<RouteBase> <x>Routes` и
  `final List<HomeCardSpec> <x>HomeCards` (может быть пустым).
- Фичи-вкладки (home, pharmacy, nutrition, workouts, profile) описывают свой **корневой маршрут** с путём из
  `AppRoutes`; подмаршруты — в `routes:` этого корневого `GoRoute`. Подмаршрут, который должен перекрыть
  NavigationBar, ставит `parentNavigatorKey: rootNavigatorKey`.
- Фичи **не импортируют друг друга**. Общее — только из `lib/core`.
- Переход в другую фичу: `context.push(AppRoutes.x)` для полноэкранных
  (`/reminders /doctors /vitals /weather /sos /assistant`), `context.go(AppRoutes.x)` — переключить вкладку.
- Контракт: `/pharmacy?q=<запрос>` открывает поиск аптеки с готовым запросом →
  `context.go(AppRoutes.pharmacySearch(q))`; экран получает `initialQuery`.
- `order` карточек на главной (меньше = выше): sos 10, weather 20, reminders 30, pharmacy 40, nutrition 50,
  workouts 60, vitals 70, doctors 80, assistant 90. Для новых карточек берите свободные числа рядом со своими.

## Паттерн репозитория (в `data/` каждой фичи)
```dart
abstract class MedicinesRepository { Future<List<Medicine>> search(String q); }
class SupabaseMedicinesRepository implements MedicinesRepository { … SupabaseClient … }
class FakeMedicinesRepository implements MedicinesRepository { … rootBundle.loadString('assets/pharmacy/medicines.json') … }

final medicinesRepositoryProvider = Provider<MedicinesRepository>((ref) =>
    ref.watch(useFakeProvider)
        ? FakeMedicinesRepository()
        : SupabaseMedicinesRepository(ref.watch(supabaseClientProvider)));
```

## Схема БД (`supabase/migrations/20261111120000_core_schema.sql`)
- **core:** `profiles` (id = auth.users.id, создаётся триггером при регистрации), `family_members`,
  `medical_records` (source `davlat|xususiy`), `lab_results`
- **B:** `medicines` (description/warning jsonb `{uz,ru,en}`, analogs text[]), `pharmacies`, `pharmacy_stock`
  (unique pharmacy+medicine), `reservations` (status `pending|ready|picked|cancelled`, **realtime**),
  `reminders` (days int[] 1=Пн…7=Вс), `reminder_logs`, `doctors`, `appointments` (status `booked|done|cancelled`)
- **C:** `foods` (name jsonb), `exercises` (name/hint jsonb), `food_logs` (meal `breakfast|lunch|dinner|snack`),
  `water_logs` (unique user_id+date), `workout_plans` (params/plan jsonb), `workout_sessions`, `vitals`
  (kind + value + value2 для давления)
- RLS на всех таблицах. Каталоги (medicines, pharmacies, pharmacy_stock, doctors, foods, exercises) — только
  select для anon и authenticated. Пользовательские — все операции только где `user_id = auth.uid()`
  (`profiles` — по `id`).

## ПРАВИЛА (обязательно)
1. Пиши **только в папках своих фич** (+ свои `assets/<модуль>/`, `tool/<модуль>/`, `test/features/<x>/`).
2. `lib/core`, `lib/app`, `pubspec.yaml`, `android/`, `ios/`, `.github/`, `supabase/config.toml` — **только лид**.
   Нужен пакет / общий виджет / константа маршрута — попроси лида.
3. Схема БД меняется только **НОВОЙ** миграцией `supabase/migrations/<timestamp>_<core|pharmacy|wellness>_<что>.sql`.
   Применённые файлы не редактировать. `supabase db push` запускает **только лид**.
4. У любой новой таблицы — RLS + политики **+ GRANT** в той же миграции: каталог —
   `grant select on public.<t> to anon, authenticated;`, пользовательская —
   `grant select, insert, update, delete on public.<t> to authenticated;`, плюс
   `grant all on public.<t> to service_role;`. Без GRANT Data API отвечает 401 `permission denied`
   (пример — `supabase/migrations/20261111150000_core_grants.sql`).
5. Supabase в фичах не инициализировать — только `ref.watch(supabaseClientProvider)`.
6. Ключи только через `env.json` (`--dart-define-from-file`). Ключ `service_role` **никогда** в коде и репозитории.
7. Без кодогенерации. Riverpod без codegen.
8. Все строки UI через `context.tr(uz: …, ru: …, en: …)`; узбекский (латиница) обязателен. jsonb-тексты — `context.trMap`.
9. У каждого репозитория Supabase- и Fake-реализация (Fake читает JSON из `assets/<модуль>/`).
   Приложение полностью работает офлайн в fake-режиме.
10. На каждом экране — состояния загрузки и ошибки: `AsyncValueView(value:, data:, onRetry:)`
    (или `AsyncValue.when` + `LoadingView` / `ErrorView`).
11. Перед коммитом: `dart format lib test`, `flutter analyze`, `flutter test` — всё зелёное.
12. Коммиты: `feat(<фича>): …`, `fix(<фича>): …`, `chore(core): …`.
13. Медицинские советы всегда с дисклеймером **«Shifokor maslahatini almashtirmaydi»**.

## Команды
```bash
flutter run --dart-define-from-file=env.json   # с Supabase
flutter run                                     # fake-режим (нет ключей)
flutter run --dart-define=USE_FAKE=true         # принудительно fake
dart format lib test && flutter analyze && flutter test
```
