import '../../../core/routing/app_routes.dart';

/// Sub-screens of the profile tab (registered in `profile_feature.dart`,
/// cover the NavigationBar).
abstract final class ProfilePaths {
  static const edit = '${AppRoutes.profile}/edit';
  static const records = '${AppRoutes.profile}/records';
  static const labs = '${AppRoutes.profile}/labs';
  static const qr = '${AppRoutes.profile}/qr';
  static const familyNew = '${AppRoutes.profile}/family/new';
  static String familyMember(String id) => '${AppRoutes.profile}/family/$id';
}
