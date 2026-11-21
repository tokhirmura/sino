import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/app/app.dart';
import 'package:sino/core/backend/backend.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/features/weather/application/weather_providers.dart';
import 'package:sino/features/weather/data/models.dart';
import 'package:sino/features/weather/data/weather_repository.dart';
import 'package:sino/features/weather/presentation/weather_screen.dart';

/// Fake demo data, counting calls; [fail] makes the next calls throw.
class _Repo implements WeatherRepository {
  _Repo(SharedPreferences prefs) : _inner = FakeWeatherRepository(prefs);

  final FakeWeatherRepository _inner;
  int calls = 0;
  bool fail = false;

  @override
  Future<WeatherReport> report(WeatherPlace place) async {
    calls++;
    if (fail) throw Exception('network down');
    return _inner.report(place);
  }

  @override
  WeatherReport? cached(String placeId) => _inner.cached(placeId);
}

/// Records whether the permission prompt was allowed.
class _Locator implements WeatherLocator {
  final asks = <bool>[];

  @override
  Future<({double lat, double lng})?> current({bool ask = true}) async {
    asks.add(ask);
    return (lat: 41.31, lng: 69.28);
  }
}

void main() {
  group('WeatherReportNotifier.refresh', () {
    late SharedPreferences prefs;
    late _Repo repo;
    late _Locator locator;
    late ProviderContainer c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'weather.place': gpsPlaceId});
      prefs = await SharedPreferences.getInstance();
      repo = _Repo(prefs);
      locator = _Locator();
      c = ProviderContainer(
        overrides: [
          useFakeProvider.overrideWithValue(true),
          sharedPreferencesProvider.overrideWithValue(prefs),
          weatherRepositoryProvider.overrideWithValue(repo),
          weatherLocatorProvider.overrideWithValue(locator),
        ],
      );
      addTearDown(c.dispose);
    });

    test('silent refresh never asks for location permission', () async {
      await c.read(weatherReportProvider.future);
      await c.read(weatherReportProvider.notifier).refresh(silent: true);
      await c.read(weatherReportProvider.notifier).refresh();
      // First load and the manual refresh may ask; the timer never does.
      expect(locator.asks, [true, false, true]);
      expect(repo.calls, 3);
    });

    test('silent failure keeps the shown report; manual one throws', () async {
      final first = await c.read(weatherReportProvider.future);
      repo.fail = true;
      await c.read(weatherReportProvider.notifier).refresh(silent: true);
      expect(c.read(weatherReportProvider).value, same(first));
      expect(c.read(weatherReportProvider).hasError, isFalse);

      await expectLater(
        c.read(weatherReportProvider.notifier).refresh(),
        throwsException,
      );
      expect(c.read(weatherReportProvider).value, same(first));
    });

    test('a refresh replaces the report without a loading state', () async {
      final first = await c.read(weatherReportProvider.future);
      final states = <AsyncValue<WeatherReport>>[];
      c.listen(weatherReportProvider, (_, s) => states.add(s));
      await c.read(weatherReportProvider.notifier).refresh(silent: true);
      expect(states, hasLength(1));
      expect(states.single.isLoading, isFalse);
      expect(states.single.value, isNot(same(first)));
    });
  });

  testWidgets('the open screen refreshes itself every minute', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'core.fake_signed_in': true});
    final prefs = await SharedPreferences.getInstance();
    final repo = _Repo(prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appOverrides(prefs: prefs, useFake: true),
          weatherRepositoryProvider.overrideWithValue(repo),
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
    expect(repo.calls, 1);

    await tester.pump(const Duration(seconds: 59));
    expect(repo.calls, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    await tester.pump(weatherAutoRefresh);
    await tester.pumpAndSettle();
    expect(repo.calls, 3);

    // Offline: the minute refresh fails quietly, the report stays.
    repo.fail = true;
    await tester.pump(weatherAutoRefresh);
    await tester.pumpAndSettle();
    expect(repo.calls, 4);
    expect(find.byKey(const Key('weather-temp')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    // The refresh button: fetches at once and reports the failure.
    await tester.tap(find.byKey(const Key('weather-refresh')));
    await tester.pumpAndSettle();
    expect(repo.calls, 5);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('weather-temp')), findsOneWidget);

    // In the background — no refreshes; back — one right away.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    repo.fail = false;
    await tester.pump(weatherAutoRefresh * 3);
    expect(repo.calls, 5);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.calls, 6);

    await tester.pumpWidget(const SizedBox());
  });
}
