# `lib/core` — общее ядро

**Владелец:** модуль A (лид). Остальные только импортируют.

Контракты (`HomeCardSpec`, `AppRoutes`, `context.tr`, провайдеры, публичные виджеты и их параметры)
меняются **только обратно совместимо**: новые параметры — с дефолтами, ничего не удалять и не переименовывать.

## Чеклист задач
- [x] P0-1 Тема и виджеты продакшн-уровня: карточки радиус 20 + мягкая тень, emoji в тонированных
  квадратах, анимированное кольцо прогресса, единые отступы, единые состояния загрузки и ошибки
  (`theme/app_tokens.dart`: `AppSpacing`, `AppShadows`; `widgets/loading_view.dart`: `LoadingView`,
  `Skeleton`, `SkeletonList`; `widgets/async_value_view.dart`: `AsyncValueView`; `errorMessage()` в
  `error_view.dart`; тесты — `test/core/widgets_test.dart`)
- [x] Дизайн 2.0 «Samarqand»: палитра бирюза/лазурь/шафран/гранат, крем и ночная темы, шрифт Inter в
  `assets/fonts`, радиус 24, градиентная шапка `AppScaffold` с гирихом (`widgets/girih_pattern.dart`), новые
  `GradientHeader`/`GradientBackdrop`, `StatTile`, `AnimatedProgressRing`, `AchievementBadge`, `SkeletonLoader`,
  `PrimaryButton`, `CascadeIn`/`Pressable` (`widgets/motion.dart`), `EmptyState(actionLabel:, onAction:)`,
  плавающая нижняя панель (`lib/app/shell_scaffold.dart`), `widgets/widgets.dart` — общий импорт.
  Пакеты для всех: flutter_animate, share_plus, screenshot, confetti, flutter_tts, pedometer, flutter_timezone
  (+ ACTIVITY_RECOGNITION / NSMotionUsageDescription, TTS_SERVICE в queries). Иконка и сплэш —
  `tool/core/gen_icon.dart` → `assets/branding/`. Тесты — `test/core/design_v2_test.dart`.
- [x] S2-3 Достижения: `data/achievements.dart` — `Achievement` (8 кодов, emoji, uz/ru/en названия и подсказки),
  `AchievementsRepository` (Supabase `achievements` + Fake в prefs `core.fake_achievements`), `achievementsProvider`;
  `AppRoutes.achievements`; миграция `20261121120000_core_achievements.sql` (RLS + GRANT)
- [x] S2-4 `AppRoutes.report`; фича-вкладка может экспортировать `<x>FullscreenRoutes` (подключены в `fullscreenRoutes`)
- [x] S2-5 `data/health_goal.dart` — `HealthGoal` (4 цели, коды `profiles.goal`, uz/ru/en), `UserProfile.goal`
  (в `toMap` только если выбрана); `widgets/goal_picker.dart` — `GoalPicker` (анкета и редактирование профиля);
  `Pill(wrap: true)` — перенос длинной подписи; миграция `20261121140000_core_profile_goal.sql`
- [x] «Oila»: `FamilyMember.phone` (+ `dialable` для `tel:`; у fake-мамы и папы есть номера), `AppRoutes.family`,
  `AppRoutes.familyMemberNew` / `familyMember(id)` (форма в профиле — чтобы другие фичи открывали её без импорта);
  миграция `20261121160000_core_family_phone.sql`
