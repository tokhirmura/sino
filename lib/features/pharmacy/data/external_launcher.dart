import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';

/// Opens a link outside the app (maps). `false` when nothing can open it.
/// Overridden in tests.
typedef ExternalLauncher = Future<bool> Function(Uri uri);

final pharmacyLauncherProvider = Provider<ExternalLauncher>(
  (ref) =>
      (uri) async => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Opens in any maps app or browser.
Uri pharmacyMapsUri(Pharmacy p) => Uri.parse(
  'https://maps.google.com/?q=${p.lat.toStringAsFixed(5)},'
  '${p.lng.toStringAsFixed(5)}',
);

/// Map tiles from the network (OpenStreetMap). `false` in tests — markers
/// and the list work without them.
final pharmacyMapTilesProvider = Provider<bool>((ref) => true);
