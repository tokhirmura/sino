import '../data/models.dart';

/// Appointment slots — there is no schedule table, so slots are generated
/// on the device from fixed working hours. Pure functions (unit-tested).

/// Working days: Monday … Saturday.
const workWeekdays = [1, 2, 3, 4, 5, 6];
const workStartHour = 9;
const workEndHour = 17;

/// Lunch break [lunchHour]:00 – [lunchHour]+1:00 has no slots.
const lunchHour = 13;
const slotMinutes = 30;

/// How many days ahead booking is open (including today).
const bookingWindowDays = 14;

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Days that can be booked: today and the next days up to
/// [bookingWindowDays], working days only.
List<DateTime> bookingDays(DateTime now) {
  final today = dayOf(now);
  return [
    for (var i = 0; i < bookingWindowDays; i++)
      DateTime(today.year, today.month, today.day + i),
  ].where((d) => workWeekdays.contains(d.weekday)).toList();
}

/// Slot start times of a working day (empty on a day off).
List<DateTime> daySlotTimes(DateTime day) {
  if (!workWeekdays.contains(day.weekday)) return const [];
  final out = <DateTime>[];
  for (var m = workStartHour * 60; m < workEndHour * 60; m += slotMinutes) {
    if (m >= lunchHour * 60 && m < (lunchHour + 1) * 60) continue;
    out.add(DateTime(day.year, day.month, day.day, m ~/ 60, m % 60));
  }
  return out;
}

/// Other patients' bookings are hidden by RLS, so the doctor's load is
/// simulated: ~30 % of slots are busy, stable per doctor and slot
/// (FNV-1a hash), the same on every device.
bool isBusySlot(String doctorId, DateTime slot) {
  var h = 0x811c9dc5;
  final key =
      '$doctorId|${slot.year}-${slot.month}-${slot.day} '
      '${slot.hour}:${slot.minute}';
  for (final c in key.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h % 100 < 30;
}

enum SlotState {
  free,

  /// Already started / in the past.
  past,

  /// Taken by another patient (simulated, see [isBusySlot]).
  busy,

  /// The user's own appointment with this doctor.
  mine,

  /// The same person already has another appointment at this time.
  clash,
}

class Slot {
  const Slot(this.at, this.state);

  final DateTime at;
  final SlotState state;

  bool get isFree => state == SlotState.free;
}

/// Slots of [doctor] on [day] for the person [memberId] (`null` = user),
/// given the user's [appointments] (any doctor, any person).
List<Slot> slotsFor(
  Doctor doctor,
  DateTime day,
  List<Appointment> appointments,
  DateTime now, {
  String? memberId,
}) {
  final active = [
    for (final a in appointments)
      if (a.status != AppointmentStatus.cancelled) a,
  ];
  return [
    for (final t in daySlotTimes(dayOf(day)))
      Slot(t, _state(doctor, t, active, now, memberId)),
  ];
}

SlotState _state(
  Doctor doctor,
  DateTime t,
  List<Appointment> active,
  DateTime now,
  String? memberId,
) {
  final end = t.add(const Duration(minutes: slotMinutes));
  bool overlaps(Appointment a) =>
      a.startsAt.isBefore(end) &&
      t.isBefore(a.startsAt.add(const Duration(minutes: slotMinutes)));
  if (active.any((a) => a.doctorId == doctor.id && overlaps(a))) {
    return SlotState.mine;
  }
  if (!t.isAfter(now)) return SlotState.past;
  if (active.any((a) => a.memberId == memberId && overlaps(a))) {
    return SlotState.clash;
  }
  if (isBusySlot(doctor.id, t)) return SlotState.busy;
  return SlotState.free;
}
