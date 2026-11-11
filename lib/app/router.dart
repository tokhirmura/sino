// Lead-only file. Assembles routes from feature_registry; no screens here.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/backend/backend.dart';
import '../core/routing/app_routes.dart';
import 'feature_registry.dart';
import 'shell_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-runs redirect whenever the session (or fake flag) changes.
  final signedIn = ValueNotifier<bool>(ref.read(isSignedInProvider));
  ref.listen<bool>(isSignedInProvider, (_, next) => signedIn.value = next);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: signedIn,
    redirect: (context, state) {
      final atOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!signedIn.value) return atOnboarding ? null : AppRoutes.onboarding;
      if (atOnboarding) return AppRoutes.home;
      return null;
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
  });
  return router;
});
