import '../../../core/routing/app_routes.dart';

/// Sub-screens of `/doctors` (registered in `doctors_feature.dart`).
abstract final class DoctorsPaths {
  static const appointments = '${AppRoutes.doctors}/appointments';
  static String doctor(String id) => '${AppRoutes.doctors}/$id';
}
