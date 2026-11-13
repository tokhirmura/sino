import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend.dart';
import '../data/models.dart';
import '../data/vitals_repository.dart';

/// Measurements of one kind for the last 7 days (today included),
/// newest first — for the charts.
final vitalsWeekProvider = FutureProvider.family<List<Vital>, VitalKind>((
  ref,
  kind,
) {
  ref.watch(authStateProvider);
  final n = DateTime.now();
  return ref
      .watch(vitalsRepositoryProvider)
      .list(kind: kind, since: DateTime(n.year, n.month, n.day - 6));
});

/// The latest measurement of a kind, `null` if none.
final latestVitalProvider = FutureProvider.family<Vital?, VitalKind>((
  ref,
  kind,
) async {
  final list = await ref.watch(vitalsWeekProvider(kind).future);
  return list.isEmpty ? null : list.first;
});
