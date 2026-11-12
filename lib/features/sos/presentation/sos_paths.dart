import '../../../core/routing/app_routes.dart';

/// Sub-screens of SOS (registered in `sos_feature.dart`).
abstract final class SosPaths {
  static String firstAid(String id) => '${AppRoutes.sos}/first-aid/$id';
}
