import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/backend/backend.dart';

/// Where the user is — to sort pharmacies by distance and center the map.
abstract class UserLocationRepository {
  /// `null` when location is off, denied or too slow — the screens then
  /// sort by price and center on Tashkent.
  Future<LatLng?> current();
}

/// Amir Temur square, Tashkent: fake location and map fallback.
const tashkentCenter = LatLng(41.31108, 69.27976);

class GeolocatorUserLocationRepository implements UserLocationRepository {
  static const timeout = Duration(seconds: 8);

  @override
  Future<LatLng?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: timeout),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}

class FakeUserLocationRepository implements UserLocationRepository {
  @override
  Future<LatLng?> current() async => tashkentCenter;
}

final userLocationRepositoryProvider = Provider<UserLocationRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeUserLocationRepository()
      : GeolocatorUserLocationRepository(),
);
