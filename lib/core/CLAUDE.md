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
