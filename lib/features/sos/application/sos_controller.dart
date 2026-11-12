import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/user.dart';
import '../data/location_repository.dart';

/// Result of holding the SOS button (demo: nothing leaves the phone
/// until the user taps «send by SMS»).
class SosAlert {
  const SosAlert({
    required this.point,
    required this.recipients,
    required this.sentAt,
  });

  final GeoPoint? point;

  /// Family member names who «got» the alert.
  final List<String> recipients;
  final DateTime sentAt;
}

/// `null` — idle; loading — locating / sending; data — sent.
class SosAlertNotifier extends Notifier<AsyncValue<SosAlert>?> {
  /// Feels like a real send in the demo.
  static const sendDelay = Duration(milliseconds: 800);

  @override
  AsyncValue<SosAlert>? build() => null;

  Future<void> trigger() async {
    if (state?.isLoading ?? false) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final results = await Future.wait([
        ref.read(locationRepositoryProvider).current(),
        ref.read(familyMembersProvider.future),
        Future<void>.delayed(sendDelay),
      ]);
      return SosAlert(
        point: results[0] as GeoPoint?,
        recipients: [for (final m in results[1] as List<FamilyMember>) m.name],
        sentAt: DateTime.now(),
      );
    });
  }

  void reset() => state = null;
}

final sosAlertProvider =
    NotifierProvider<SosAlertNotifier, AsyncValue<SosAlert>?>(
      SosAlertNotifier.new,
    );

/// Opens the dialer / SMS app. Never calls by itself: `tel:` only fills
/// the number. Overridden in tests.
final externalLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

Uri telUri(String number) => Uri(scheme: 'tel', path: number);

/// `sms:?body=…` — body encoded with %20 (not +), which all SMS apps read.
Uri smsUri(String body) => Uri.parse('sms:?body=${Uri.encodeComponent(body)}');
