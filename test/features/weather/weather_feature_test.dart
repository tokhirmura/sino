import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/weather/application/weather_providers.dart';
import 'package:sino/features/weather/data/models.dart';
import 'package:sino/features/weather/data/weather_repository.dart';
import 'package:sino/features/weather/presentation/weather_screen.dart';
import 'package:sino/features/weather/weather_feature.dart';

Future<SharedPreferences> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  List overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'core.fake_signed_in': true,
    ...prefs,
  });
  final p = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appOverrides(prefs: p, useFake: true),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: AppLang.uz.locale,
        supportedLocales: AppLang.locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const WeatherScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return p;
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  test('weather exposes its root route', () {
    final paths = [for (final r in weatherRoutes.whereType<GoRoute>()) r.path];
    expect(paths, contains(AppRoutes.weather));
  });

  testWidgets('Tashkent → Samarkand → my location (fake mode)', (tester) async {
    final prefs = await _pump(tester);

    // Tashkent by default: bad air → «train at home».
    expect(_text(tester, 'weather-place'), 'Toshkent');
    expect(_text(tester, 'weather-temp'), '11°');
    expect(_text(tester, 'weather-aqi'), '135');
    expect(_text(tester, 'weather-aqi-level'), 'Sezgir guruhlar uchun zararli');
    expect(find.byKey(const Key('weather-tip-airSensitive')), findsOneWidget);
    expect(find.byKey(const Key('weather-home-workout')), findsOneWidget);
    expect(find.byKey(const Key('weather-hours')), findsOneWidget);
    expect(find.text('Bugun'), findsOneWidget); // 7 days
    expect(find.byKey(const Key('weather-offline')), findsNothing);
    expect(jsonDecode(prefs.getString(todayAqiKey)!)['aqi'], 135);

    await tester.tap(find.byKey(const Key('weather-place-samarkand')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'weather-place'), 'Samarqand');
    expect(_text(tester, 'weather-temp'), '9°');
    expect(_text(tester, 'weather-aqi'), '58');
    expect(find.byKey(const Key('weather-tip-goodDay')), findsOneWidget);
    expect(find.byKey(const Key('weather-home-workout')), findsNothing);
    expect(prefs.getString(WeatherPlaceNotifier.key), 'samarkand');
    expect(jsonDecode(prefs.getString(todayAqiKey)!)['aqi'], 58);

    await tester.tap(find.byKey(const Key('weather-place-gps')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'weather-place'), 'Joylashuvim · Toshkent');
  });

  testWidgets('airplane mode: the last saved forecast with a banner', (
    tester,
  ) async {
    // A forecast saved 3 hours ago, then the network is gone.
    final saved = FakeWeatherRepository.fakeReport(
      weatherCities.first,
      Map<String, dynamic>.from(
        (jsonDecode(
              File('assets/wellness/fake_weather.json').readAsStringSync(),
            ) as Map)['tashkent']
            as Map,
      ),
      DateTime.now().subtract(const Duration(hours: 3)),
    );
    final offline = MockClient(
      (_) async => throw const SocketException('Network is unreachable'),
    );
    await _pump(
      tester,
      prefs: {
        '${WeatherCache.prefix}tashkent': jsonEncode(saved.toJson()),
        WeatherCache.lastKey: 'tashkent',
      },
      overrides: [
        weatherRepositoryProvider.overrideWith(
          (ref) => OpenMeteoWeatherRepository(
            offline,
            ref.watch(sharedPreferencesProvider),
          ),
        ),
      ],
    );
    expect(find.byKey(const Key('weather-offline')), findsOneWidget);
    expect(
      find.textContaining(
        'Internet yo‘q — oxirgi saqlangan prognoz (3 soat oldin)',
      ),
      findsOneWidget,
    );
    expect(_text(tester, 'weather-temp'), '11°');
    expect(_text(tester, 'weather-aqi'), '135');

    // A city never opened before: the last saved one, said explicitly.
    await tester.tap(find.byKey(const Key('weather-place-samarkand')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Bu shahar uchun saqlangan prognoz yo‘q'),
      findsOneWidget,
    );
    expect(_text(tester, 'weather-place'), 'Toshkent');
  });

  testWidgets('offline and nothing saved → error with retry', (tester) async {
    final offline = MockClient(
      (_) async => throw const SocketException('Network is unreachable'),
    );
    await _pump(
      tester,
      overrides: [
        weatherRepositoryProvider.overrideWith(
          (ref) => OpenMeteoWeatherRepository(
            offline,
            ref.watch(sharedPreferencesProvider),
          ),
        ),
      ],
    );
    expect(find.textContaining('Internet aloqasi yo‘q'), findsOneWidget);
  });

  testWidgets('location denied → message, cities still work', (tester) async {
    await _pump(
      tester,
      prefs: {WeatherPlaceNotifier.key: gpsPlaceId},
      overrides: [weatherLocatorProvider.overrideWithValue(_NoLocation())],
    );
    expect(find.text('Joylashuv aniqlanmadi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('weather-place-tashkent')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'weather-place'), 'Toshkent');
  });

  testWidgets('home card: temperature, city and AQI', (tester) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'core.fake_signed_in': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(prefs: prefs, useFake: true),
        child: const SinoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(_text(tester, 'weather-home-temp'), '11° · Toshkent');
    expect(find.text('AQI 135'), findsOneWidget);
    expect(
      _text(tester, 'weather-home-subtitle'),
      'Bugun mashg‘ulotni uyda qiling',
    );
    await tester.tap(find.byKey(const Key('weather-home-card')));
    await tester.pumpAndSettle();
    expect(find.byType(WeatherScreen), findsOneWidget);
  });
}

class _NoLocation implements WeatherLocator {
  @override
  Future<({double lat, double lng})?> current() async => null;
}
