import '../../../core/routing/app_routes.dart';

/// Sub-screens of `/reminders` (registered in `reminders_feature.dart`).
abstract final class RemindersPaths {
  static const create = '${AppRoutes.reminders}/new';
  static const history = '${AppRoutes.reminders}/history';
  static String edit(String id) => '${AppRoutes.reminders}/$id';
}
