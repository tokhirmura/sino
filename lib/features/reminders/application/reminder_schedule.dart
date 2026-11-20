import '../data/models.dart';

/// Pure schedule rules (no Riverpod) — unit-tested directly.

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// The log of [reminder]'s dose on [day] (match: same reminder, same local
/// date of `taken_at`), or `null`.
ReminderLog? logFor(Reminder reminder, DateTime day, List<ReminderLog> logs) {
  final key = dateKey(day);
  for (final l in logs) {
    if (l.reminderId == reminder.id && dateKey(l.takenAt) == key) return l;
  }
  return null;
}

/// Doses of [day], by time. Only active reminders on their weekdays; a dose
/// that was already taken is shown even if the reminder was paused since.
List<Dose> dosesForDay(
  DateTime day,
  List<Reminder> reminders,
  List<ReminderLog> logs,
) {
  final d = dayOf(day);
  final out = <Dose>[];
  for (final r in reminders) {
    final log = logFor(r, d, logs);
    if (!r.isScheduledOn(d) && log == null) continue;
    out.add(Dose(reminder: r, scheduledAt: r.at(d), log: log));
  }
  out.sort((a, b) {
    final c = a.scheduledAt.compareTo(b.scheduledAt);
    return c != 0 ? c : a.reminder.name.compareTo(b.reminder.name);
  });
  return out;
}

/// The next dose not yet taken that is due or upcoming, looking up to a
/// week ahead; `null` when there is none.
Dose? nextDose(DateTime now, List<Reminder> reminders, List<ReminderLog> logs) {
  final today = dayOf(now);
  for (var i = 0; i < 8; i++) {
    final day = DateTime(today.year, today.month, today.day + i);
    for (final d in dosesForDay(day, reminders, logs)) {
      final s = d.status(now);
      if (s == DoseStatus.due || s == DoseStatus.upcoming) return d;
    }
  }
  return null;
}

/// Doses taken out of doses that were expected, over a period.
class Adherence {
  const Adherence({required this.taken, required this.expected});

  final int taken;
  final int expected;

  /// 0…1; `null` when nothing was expected.
  double? get ratio => expected == 0 ? null : taken / expected;

  /// Rounded percentage; `null` when nothing was expected.
  int? get percent => ratio == null ? null : (ratio! * 100).round();
}

/// Adherence over the last [days] days including today. A dose is
/// «expected» once it is taken or its grace period is over (so today's
/// upcoming doses don't lower the score) and only if the reminder already
/// existed at its time.
Adherence adherence(
  DateTime now,
  List<Reminder> reminders,
  List<ReminderLog> logs, {
  int days = 7,
}) {
  final today = dayOf(now);
  var taken = 0;
  var expected = 0;
  for (var i = 0; i < days; i++) {
    final day = DateTime(today.year, today.month, today.day - i);
    for (final d in dosesForDay(day, reminders, logs)) {
      final created = d.reminder.createdAt;
      if (!d.taken && created != null && d.scheduledAt.isBefore(created)) {
        continue;
      }
      switch (d.status(now)) {
        case DoseStatus.taken:
          taken++;
          expected++;
        case DoseStatus.missed:
          expected++;
        case DoseStatus.due:
        case DoseStatus.upcoming:
          break;
      }
    }
  }
  return Adherence(taken: taken, expected: expected);
}
