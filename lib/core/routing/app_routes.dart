import 'package:flutter/widgets.dart';

/// Paths of all screens. Navigation between features ONLY via these
/// constants: `context.push(AppRoutes.x)` for full-screen routes,
/// `context.go(AppRoutes.x)` to switch to a bottom tab.
abstract final class AppRoutes {
  // Bottom tabs (StatefulShellRoute)
  static const home = '/home';
  static const pharmacy = '/pharmacy';
  static const nutrition = '/nutrition';
  static const workouts = '/workouts';
  static const profile = '/profile';

  // Full-screen (outside the shell)
  static const reminders = '/reminders';
  static const doctors = '/doctors';
  static const vitals = '/vitals';
  static const weather = '/weather';
  static const sos = '/sos';
  static const assistant = '/assistant';
  static const onboarding = '/onboarding';

  /// Contract: `/pharmacy?q=<query>` opens pharmacy search pre-filled.
  static String pharmacySearch(String query) =>
      Uri(path: pharmacy, queryParameters: {'q': query}).toString();
}

/// Root navigator. Use `parentNavigatorKey: rootNavigatorKey` for a
/// feature sub-route that must cover the bottom navigation bar.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
