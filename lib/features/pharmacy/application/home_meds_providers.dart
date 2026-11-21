import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend.dart';
import '../data/home_meds_repository.dart';

export '../data/home_meds_repository.dart' show homeMedsClockProvider;
import 'write_queue.dart';

/// Warn this many days before a home medicine expires.
const expiryWarningDays = 30;

enum ExpiryState {
  /// Past the expiry date (the last valid day is the date itself).
  expired,

  /// Expires within [expiryWarningDays] days.
  soon,
  ok,

  /// No expiry date entered.
  unknown,
}

/// Whole days from today to the expiry date (0 = expires today, negative =
/// expired); `null` without a date.
int? daysUntilExpiry(HomeMed m, DateTime now) {
  final e = m.expiryDate;
  if (e == null) return null;
  // Date-only difference in UTC — no DST hour shifts.
  return DateTime.utc(
    e.year,
    e.month,
    e.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
}

ExpiryState expiryState(HomeMed m, DateTime now) {
  final d = daysUntilExpiry(m, now);
  if (d == null) return ExpiryState.unknown;
  if (d < 0) return ExpiryState.expired;
  if (d <= expiryWarningDays) return ExpiryState.soon;
  return ExpiryState.ok;
}

/// Expired first, then by expiry date; no date last; then by name.
List<HomeMed> sortHomeMeds(List<HomeMed> list) => [...list]
  ..sort((a, b) {
    final ea = a.expiryDate, eb = b.expiryDate;
    if (ea != null && eb != null && ea != eb) return ea.compareTo(eb);
    if (ea == null && eb != null) return 1;
    if (ea != null && eb == null) return -1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

enum HomeMedProblem { emptyName, badQuantity }

class HomeMedException implements Exception {
  const HomeMedException(this.problem);

  final HomeMedProblem problem;

  @override
  String toString() => 'HomeMedException(${problem.name})';
}

/// The home cabinet, sorted ([sortHomeMeds]), with optimistic add / edit /
/// remove: the UI changes at once, a failed write rolls back and rethrows.
class HomeMedsNotifier extends AsyncNotifier<List<HomeMed>> {
  final _queue = WriteQueue();

  HomeMedsRepository get _repo => ref.read(homeMedsRepositoryProvider);

  List<HomeMed> get _current => state.value ?? const [];

  @override
  Future<List<HomeMed>> build() async {
    ref.watch(authStateProvider);
    return sortHomeMeds(await ref.watch(homeMedsRepositoryProvider).list());
  }

  Future<void> _ready() async {
    final err = state.error;
    if (state.hasError && err != null) {
      Error.throwWithStackTrace(err, state.stackTrace ?? StackTrace.current);
    }
    if (state.isLoading) await future;
  }

  static void _validate(HomeMed m) {
    if (m.name.trim().isEmpty) {
      throw const HomeMedException(HomeMedProblem.emptyName);
    }
    if (m.quantity < 0 || m.quantity > 999) {
      throw const HomeMedException(HomeMedProblem.badQuantity);
    }
  }

  void _set(List<HomeMed> list) {
    if (ref.mounted) state = AsyncData(sortHomeMeds(list));
  }

  Future<HomeMed> add(HomeMed draft) async {
    _validate(draft);
    await _ready();
    final temp = draft.copyWith(id: newPendingId());
    _set([..._current, temp]);
    try {
      final saved = await _queue.run(() => _repo.add(draft));
      _set([for (final m in _current) m.id == temp.id ? saved : m]);
      return saved;
    } catch (_) {
      _set([
        for (final m in _current)
          if (m.id != temp.id) m,
      ]);
      rethrow;
    }
  }

  Future<void> edit(HomeMed med) async {
    _validate(med);
    await _ready();
    HomeMed? old;
    for (final m in _current) {
      if (m.id == med.id) old = m;
    }
    if (old == null || isPendingId(med.id)) return;
    _set([for (final m in _current) m.id == med.id ? med : m]);
    try {
      final saved = await _queue.run(() => _repo.update(med));
      _set([for (final m in _current) m.id == med.id ? saved : m]);
    } catch (_) {
      _set([for (final m in _current) m.id == med.id ? old : m]);
      rethrow;
    }
  }

  /// Removes and returns the medicine (for «undo»), or `null`.
  Future<HomeMed?> remove(String id) async {
    await _ready();
    HomeMed? removed;
    for (final m in _current) {
      if (m.id == id) removed = m;
    }
    if (removed == null || isPendingId(id)) return null;
    _set([
      for (final m in _current)
        if (m.id != id) m,
    ]);
    try {
      await _queue.run(() => _repo.remove(id));
      return removed;
    } catch (_) {
      _set([..._current, removed]);
      rethrow;
    }
  }
}

final homeMedsProvider = AsyncNotifierProvider<HomeMedsNotifier, List<HomeMed>>(
  HomeMedsNotifier.new,
);

/// Counts for the summary: all, expiring within 30 days, expired.
typedef HomeMedsSummary = ({int total, int soon, int expired});

final homeMedsSummaryProvider = Provider<AsyncValue<HomeMedsSummary>>((ref) {
  final now = ref.watch(homeMedsClockProvider)();
  return ref.watch(homeMedsProvider).whenData((list) {
    var soon = 0, expired = 0;
    for (final m in list) {
      switch (expiryState(m, now)) {
        case ExpiryState.soon:
          soon++;
        case ExpiryState.expired:
          expired++;
        case ExpiryState.ok || ExpiryState.unknown:
          break;
      }
    }
    return (total: list.length, soon: soon, expired: expired);
  });
});
