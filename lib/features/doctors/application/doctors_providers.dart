import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend.dart';
import '../data/doctors_repository.dart';
import '../data/models.dart';
import 'doctor_slots.dart';
import 'write_queue.dart';

/// Whole `doctors` catalog, best rated first.
final doctorsCatalogProvider = FutureProvider<List<Doctor>>(
  (ref) => ref.watch(doctorsRepositoryProvider).doctors(),
);

final doctorsByIdProvider = FutureProvider<Map<String, Doctor>>((ref) async {
  final list = await ref.watch(doctorsCatalogProvider.future);
  return {for (final d in list) d.id: d};
});

/// Specialties present in the catalog, in [doctorSpecialties] order
/// (unknown slugs last) — the filter chips.
final specialtiesProvider = FutureProvider<List<String>>((ref) async {
  final list = await ref.watch(doctorsCatalogProvider.future);
  final present = {for (final d in list) d.specialty};
  return [
    for (final s in doctorSpecialties)
      if (present.contains(s)) s,
    ...present.where((s) => !doctorSpecialties.contains(s)).toList()..sort(),
  ];
});

enum AppointmentProblem {
  /// The slot is not free any more (past, busy, clash, already booked).
  slotUnavailable,

  /// Online visit with a doctor who doesn't consult online.
  onlineNotSupported,

  /// Already cancelled or done.
  notCancellable,
}

class AppointmentException implements Exception {
  const AppointmentException(this.problem);

  final AppointmentProblem problem;

  @override
  String toString() => 'AppointmentException(${problem.name})';
}

/// The user's appointments by time (all statuses), with optimistic book /
/// cancel: the UI changes at once, a failed write rolls back and rethrows.
class AppointmentsNotifier extends AsyncNotifier<List<Appointment>> {
  final _queue = WriteQueue();

  DoctorsRepository get _repo => ref.read(doctorsRepositoryProvider);

  List<Appointment> get _current => state.value ?? const [];

  @override
  Future<List<Appointment>> build() {
    ref.watch(authStateProvider);
    return ref.watch(doctorsRepositoryProvider).appointments();
  }

  Future<void> _ready() async {
    final err = state.error;
    if (state.hasError && err != null) {
      Error.throwWithStackTrace(err, state.stackTrace ?? StackTrace.current);
    }
    if (state.isLoading) await future;
  }

  static List<Appointment> _sorted(List<Appointment> l) =>
      [...l]..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  /// Books [doctor] at [startsAt] (a slot from [slotsFor]) for [memberId]
  /// (`null` = the user). Throws [AppointmentException] before any write
  /// when the slot is not free.
  Future<Appointment> book(
    Doctor doctor,
    DateTime startsAt, {
    String? memberId,
    bool online = false,
  }) async {
    if (online && !doctor.online) {
      throw const AppointmentException(AppointmentProblem.onlineNotSupported);
    }
    await _ready();
    final now = DateTime.now();
    final slot = slotsFor(
      doctor,
      startsAt,
      _current,
      now,
      memberId: memberId,
    ).where((s) => s.at == startsAt);
    if (slot.isEmpty || !slot.first.isFree) {
      throw const AppointmentException(AppointmentProblem.slotUnavailable);
    }
    final temp = Appointment(
      id: newPendingId(),
      doctorId: doctor.id,
      memberId: memberId,
      startsAt: startsAt,
      online: online,
      createdAt: now,
      doctor: doctor,
    );
    if (ref.mounted) state = AsyncData(_sorted([..._current, temp]));
    try {
      final saved = await _queue.run(
        () => _repo.book(
          doctorId: doctor.id,
          startsAt: startsAt,
          memberId: memberId,
          online: online,
        ),
      );
      final full = saved.doctor == null
          ? saved.copyWith(doctor: doctor)
          : saved;
      if (ref.mounted) {
        state = AsyncData([
          for (final a in _current) a.id == temp.id ? full : a,
        ]);
      }
      return full;
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData([
          for (final a in _current)
            if (a.id != temp.id) a,
        ]);
      }
      rethrow;
    }
  }

  Future<void> cancel(String id) async {
    await _ready();
    Appointment? old;
    for (final a in _current) {
      if (a.id == id) old = a;
    }
    if (old == null || isPendingId(id) || !ref.mounted) return;
    if (old.status != AppointmentStatus.booked) {
      throw const AppointmentException(AppointmentProblem.notCancellable);
    }
    _setStatus(id, AppointmentStatus.cancelled);
    try {
      await _queue.run(() => _repo.cancel(id));
    } catch (_) {
      if (ref.mounted) _setStatus(id, old.status);
      rethrow;
    }
  }

  void _setStatus(String id, AppointmentStatus status) {
    state = AsyncData([
      for (final a in _current) a.id == id ? a.copyWith(status: status) : a,
    ]);
  }
}

final appointmentsProvider =
    AsyncNotifierProvider<AppointmentsNotifier, List<Appointment>>(
      AppointmentsNotifier.new,
    );

/// Booked appointments still ahead, soonest first (home card, «Mening
/// yozuvlarim»).
final upcomingAppointmentsProvider = Provider<AsyncValue<List<Appointment>>>((
  ref,
) {
  final now = DateTime.now();
  return ref
      .watch(appointmentsProvider)
      .whenData(
        (l) => [
          for (final a in l)
            if (a.isUpcoming(now)) a,
        ],
      );
});

/// Past and cancelled appointments, newest first.
final pastAppointmentsProvider = Provider<AsyncValue<List<Appointment>>>((ref) {
  final now = DateTime.now();
  return ref
      .watch(appointmentsProvider)
      .whenData(
        (l) => [
          for (final a in l.reversed)
            if (!a.isUpcoming(now)) a,
        ],
      );
});

/// Key of [doctorSlotsProvider]: doctor, day (date only) and the person.
typedef SlotsKey = ({String doctorId, DateTime day, String? memberId});

/// Slots of a doctor on a day for a person, kept in sync with the user's
/// appointments.
final doctorSlotsProvider = Provider.family<AsyncValue<List<Slot>>, SlotsKey>((
  ref,
  key,
) {
  final doctors = ref.watch(doctorsByIdProvider);
  final appts = ref.watch(appointmentsProvider);
  for (final v in <AsyncValue<Object>>[doctors, appts]) {
    if (v.hasError) {
      return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
    }
  }
  if (!doctors.hasValue || !appts.hasValue) return const AsyncLoading();
  final doctor = doctors.requireValue[key.doctorId];
  if (doctor == null) return const AsyncData([]);
  return AsyncData(
    slotsFor(
      doctor,
      key.day,
      appts.requireValue,
      DateTime.now(),
      memberId: key.memberId,
    ),
  );
});
