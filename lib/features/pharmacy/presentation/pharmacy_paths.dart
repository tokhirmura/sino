import '../../../core/routing/app_routes.dart';

/// Sub-screens of the pharmacy tab (registered in `pharmacy_feature.dart`,
/// cover the NavigationBar).
abstract final class PharmacyPaths {
  static String medicine(String id) => '${AppRoutes.pharmacy}/medicine/$id';
  static const pharmacies = '${AppRoutes.pharmacy}/pharmacies';
  static const reservations = '${AppRoutes.pharmacy}/reservations';
  static const scan = '${AppRoutes.pharmacy}/scan';
  static const homeMeds = '${AppRoutes.pharmacy}/home-meds';
}
