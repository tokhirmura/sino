import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/weather/weather_feature.dart';
import 'package:sino/features/weather/presentation/weather_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('weather exposes its root route', () {
    final paths = [for (final r in weatherRoutes.whereType<GoRoute>()) r.path];
    expect(paths, contains(AppRoutes.weather));
  });

  testWidgets('weather screen renders stub (fake mode)', (tester) async {
    await pumpScreen(tester, const WeatherScreen());
    expect(find.text('Ob-havo — tez orada'), findsOneWidget);
  });
}
