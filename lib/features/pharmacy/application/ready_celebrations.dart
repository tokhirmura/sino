import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import 'pharmacy_providers.dart';

/// Reservations that just went `pending → ready` and haven't been
/// celebrated yet (a queue). Screens that host the celebration
/// (`ReadyCelebrationHost`) [take] from it, so one transition is celebrated
/// once even when several hosts are mounted (home card + pharmacy tab).
class ReadyCelebrationsNotifier extends Notifier<List<Reservation>> {
  @override
  List<Reservation> build() {
    ref.listen(reservationsProvider, (prev, next) {
      final before = {
        for (final r in prev?.value ?? const <Reservation>[]) r.id: r.status,
      };
      final fresh = [
        for (final r in next.value ?? const <Reservation>[])
          if (before[r.id] == ReservationStatus.pending &&
              r.status == ReservationStatus.ready)
            r,
      ];
      if (fresh.isNotEmpty) state = [...state, ...fresh];
    });
    return const [];
  }

  /// The next reservation to celebrate (removed from the queue), or `null`.
  Reservation? take() {
    if (state.isEmpty) return null;
    final first = state.first;
    state = state.sublist(1);
    return first;
  }
}

final readyCelebrationsProvider =
    NotifierProvider<ReadyCelebrationsNotifier, List<Reservation>>(
      ReadyCelebrationsNotifier.new,
    );
