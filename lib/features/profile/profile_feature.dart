import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/doctor_qr_screen.dart';
import 'presentation/edit_profile_screen.dart';
import 'presentation/family_member_screen.dart';
import 'presentation/lab_results_screen.dart';
import 'presentation/medical_records_screen.dart';
import 'presentation/profile_screen.dart';

/// The ONLY public file of the `profile` feature.
final List<RouteBase> profileRoutes = [
  GoRoute(
    path: AppRoutes.profile,
    builder: (context, state) => const ProfileScreen(),
    routes: [
      GoRoute(
        path: 'edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: 'records',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MedicalRecordsScreen(),
      ),
      GoRoute(
        path: 'labs',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LabResultsScreen(),
      ),
      GoRoute(
        path: 'qr',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DoctorQrScreen(),
      ),
      GoRoute(
        path: 'family/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FamilyMemberScreen(),
      ),
      GoRoute(
        path: 'family/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            FamilyMemberScreen(memberId: state.pathParameters['id']),
      ),
    ],
  ),
];

final List<HomeCardSpec> profileHomeCards = const [];
