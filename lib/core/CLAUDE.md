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
- [x] Общий сервис уведомлений `notifications/local_notifications.dart` (раздел ниже; тест —
  `test/core/local_notifications_test.dart`)

## Уведомления (`notifications/local_notifications.dart`)
Один сервис `flutter_local_notifications` на всё приложение: `ref.read(appNotificationsProvider)` —
`LocalAppNotifications` на Android/iOS, `NoopAppNotifications` на web/desktop и в `flutter test` (выбор автоматический).
- `init()` — один раз (Future кэшируется): база часовых поясов, `tz.local` = зона устройства из `flutter_timezone`
  (не вышло — зона с тем же смещением, затем UTC), `initialize` плагина (на iOS разрешения не спрашивает).
  Остальные методы вызывают его сами.
- `requestPermission()` — Android 13+ / iOS.
- `schedule(id:, at:, title:, body:, payload:, channel:, repeat:)` — обёртка над `zonedSchedule` (неточный режим,
  без exact-alarm; `repeat: DateTimeComponents.time` — каждый день, `dayOfWeekAndTime` — каждую неделю).
- `cancel(id)`, `pendingNotificationRequests()`, `cancelByPayloadPrefix(prefix)`.
- `nextLocalTime(hour, minute, weekday:)` — ближайшее время в `tz.local` (после `init()`).
- Любая ошибка платформы глотается (`debugPrint`): приложение работает и без уведомлений.

| Модуль | id (`NotificationIds`) | payload (`NotificationPayloads`) | канал (`AppNotificationChannel`) |
|---|---|---|---|
| B reminders | 0 … 1 999 999 999 (`< remindersEnd`) | `reminder:` | `reminders` = `sino_reminders` |
| C wellness | 2 100 000 000 … 2 139 999 999 (`wellnessBase`) | `wellness:` | `wellness` = `sino_wellness` |
| A core | 2 140 000 000 … 2 147 483 647 (`coreBase`) | `core:` | `core` = `sino_core` |

id на Android — int32 (максимум 2 147 483 647 = `NotificationIds.max`), поэтому у A не «2 200 000 000+»;
id вне диапазона сервис не ставит.

### Как перейти (B и C делают сами, в своих папках)
1. Убрать из своего `*_notifications.dart` `FlutterLocalNotificationsPlugin`, `_init`, `deviceLocation`, свой
   `requestPermission` и выбор Noop/Local.
2. Свой класс получает сервис: `Provider((ref) => LocalReminderNotifications(ref.watch(appNotificationsProvider)))`.
3. Планирование: `n.schedule(id: …, at: nextLocalTime(h, m, weekday: d), title: …, body: …,
   payload: '${NotificationPayloads.reminder}$id', channel: AppNotificationChannel.reminders,
   repeat: DateTimeComponents.dayOfWeekAndTime)`; разрешение — `n.requestPermission()`.
4. B при синхронизации: `await n.cancelByPayloadPrefix(NotificationPayloads.reminder)`, затем `schedule` заново.
   C: `n.cancel(id)` для своих id (`NotificationIds.wellnessBase + …`).
5. Тесты: подменять `appNotificationsProvider` своим фейком (`implements AppNotifications`) или оставить Noop.
6. Каналы прежние: `AppNotificationChannel.reminders` / `wellness` — те же id и названия, что сейчас у B и C.
