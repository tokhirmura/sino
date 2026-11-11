import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/home/home_feature.dart';
import 'package:sino/features/home/presentation/home_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('home exposes its root route', () {
    final paths = [for (final r in homeRoutes.whereType<GoRoute>()) r.path];
    expect(paths, contains(AppRoutes.home));
  });

  testWidgets('home shows greeting and feature cards (fake mode)', (
    tester,
  ) async {
    await pumpScreen(tester, const HomeScreen());
    expect(find.text('Salom, Aziz'), findsOneWidget);
    expect(find.text('Dorixona'), findsOneWidget);
  });
}
