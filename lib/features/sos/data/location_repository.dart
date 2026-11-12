import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/backend/backend.dart';

class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// Opens in any maps app or browser.
  String get mapsUrl =>
      'https://maps.google.com/?q=${lat.toStringAsFixed(5)},'
      '${lng.toStringAsFixed(5)}';
}

/// Where the user is right now, for the SOS message.
abstract class LocationRepository {
  /// `null` when location is off, denied or too slow — SOS still works.
  Future<GeoPoint?> current();
}

class GeolocatorLocationRepository implements LocationRepository {
  static const timeout = Duration(seconds: 8);

  @override
  Future<GeoPoint?> current() async {
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
      return GeoPoint(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}

/// Offline: Amir Temur square, Tashkent.
class FakeLocationRepository implements LocationRepository {
  static const tashkent = GeoPoint(41.31108, 69.27976);

  @override
  Future<GeoPoint?> current() async => tashkent;
}

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeLocationRepository()
      : GeolocatorLocationRepository(),
);
