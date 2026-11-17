import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend.dart';
import '../../../core/storage/prefs.dart';
import '../data/models.dart';
import '../data/vitals_repository.dart';
import 'vitals_math.dart';

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

/// All measurements of the last 7 days (today included), newest first —
/// one request for the whole screen and the home card.
final vitalsWeekAllProvider = FutureProvider<List<Vital>>((ref) {
  ref.watch(authStateProvider);
  final n = DateTime.now();
  return ref
      .watch(vitalsRepositoryProvider)
      .list(since: DateTime(n.year, n.month, n.day - 6));
});

/// The latest measurement of a kind, `null` if none.
final latestVitalProvider = FutureProvider.family<Vital?, VitalKind>((
  ref,
  kind,
) async {
  final list = await ref.watch(vitalsWeekProvider(kind).future);
  return list.isEmpty ? null : list.first;
});

/// Kind shown on the vitals screen (chart, list, «add»).
class SelectedVitalKindNotifier extends Notifier<VitalKind> {
  @override
  VitalKind build() => VitalKind.pulse;

  void select(VitalKind k) => state = k;
}

final selectedVitalKindProvider =
    NotifierProvider<SelectedVitalKindNotifier, VitalKind>(
      SelectedVitalKindNotifier.new,
    );

/// Developer mode: unlocked by tapping the screen title 5 times; shows the
/// «fill test history» button. Per device (prefs).
class VitalsDevModeNotifier extends Notifier<bool> {
  static const key = 'vitals.dev_mode';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(key) ?? false;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(sharedPreferencesProvider).setBool(key, on);
  }
}

final vitalsDevModeProvider = NotifierProvider<VitalsDevModeNotifier, bool>(
  VitalsDevModeNotifier.new,
);

/// Writes to `vitals`; every write refreshes the charts.
class VitalsActions {
  VitalsActions(this._ref);

  final Ref _ref;

  VitalsRepository get _repo => _ref.read(vitalsRepositoryProvider);

  void _refresh() {
    _ref.invalidate(vitalsWeekProvider);
    _ref.invalidate(vitalsWeekAllProvider);
  }

  Future<Vital> add({
    required VitalKind kind,
    required double value,
    double? value2,
    DateTime? measuredAt,
  }) async {
    final v = await _repo.add(
      kind: kind,
      value: value,
      value2: value2,
      measuredAt: measuredAt,
    );
    _refresh();
    return v;
  }

  Future<void> remove(String id) async {
    await _repo.remove(id);
    _refresh();
  }

  /// Fills every empty day × kind of the last 7 days; returns how many
  /// measurements were added (0 — the week is already full).
  Future<int> fillTestHistory() async {
    final now = DateTime.now();
    final existing = await _repo.list(
      since: DateTime(now.year, now.month, now.day - 6),
    );
    final items = testHistory(existing, now);
    await _repo.addAll(items);
    _refresh();
    return items.length;
  }
}

final vitalsActionsProvider = Provider<VitalsActions>(VitalsActions.new);
