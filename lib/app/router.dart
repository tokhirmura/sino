// Lead-only file. Assembles routes from feature_registry; no screens here.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/backend/backend.dart';
import '../core/data/user.dart';
import '../core/routing/app_routes.dart';
import 'feature_registry.dart';
import 'shell_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-runs redirect whenever the session (or fake flag) or the
  // profile-completeness gate changes.
  final signedIn = ValueNotifier<bool>(ref.read(isSignedInProvider));
  final gate = ValueNotifier<ProfileGate>(ref.read(profileGateProvider));
  ref.listen<bool>(isSignedInProvider, (_, next) => signedIn.value = next);
  ref.listen<ProfileGate>(profileGateProvider, (_, next) => gate.value = next);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: Listenable.merge([signedIn, gate]),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final atOnboarding = location == AppRoutes.onboarding;
      final atSetup = location == AppRoutes.profileSetup;
      if (!signedIn.value) return atOnboarding ? null : AppRoutes.onboarding;
      return switch (gate.value) {
        // Profile is loading: stay put (avoids a flash of home / setup).
        ProfileGate.loading => null,
        ProfileGate.needsSetup => atSetup ? null : AppRoutes.profileSetup,
        ProfileGate.ready => atOnboarding || atSetup ? AppRoutes.home : null,
      };
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellScaffold(shell: shell),
        branches: [
          for (final routes in tabBranchRoutes)
            StatefulShellBranch(routes: routes),
        ],
      ),
      ...fullscreenRoutes,
    ],
  );

  ref.onDispose(() {
    router.dispose();
    signedIn.dispose();
    gate.dispose();
  });
  return router;
});
