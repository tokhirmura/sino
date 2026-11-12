import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/one_id_provider.dart';

/// Biometrics + registry data. Auto-disposed when the OneID step closes,
/// so re-entering the step scans again; `ref.invalidate` retries.
final oneIdVerificationProvider = FutureProvider.autoDispose<OneIdProfile>(
  (ref) => ref.watch(oneIdAuthProvider).verify(),
);
