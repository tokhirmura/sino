/// Models of the reminders feature (tables `reminders`, `reminder_logs`).
/// Hand-written `fromJson`/`toJson`, no codegen.
library;

/// `yyyy-MM-dd` of a local date.
String dateKey(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

DateTime? _time(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

/// All weekdays, 1 = Monday … 7 = Sunday (as `reminders.days`).
const allWeekdays = [1, 2, 3, 4, 5, 6, 7];

/// A row of `reminders`: take [name] [dose] every [days] at [hour]:[minute]
/// (device local time). One time per row — «3 times a day» is 3 rows.
class Reminder {
  const Reminder({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
    this.memberId,
    this.dose,
    this.days = allWeekdays,
    this.active = true,
    this.createdAt,
  });

  final String id;

  /// `family_members.id`; `null` = for the user.
  final String? memberId;
  final String name;
  final String? dose;
  final int hour;
  final int minute;

  /// Sorted, unique, 1 = Monday … 7 = Sunday.
  final List<int> days;
  final bool active;
  final DateTime? createdAt;

  bool get everyDay => days.length == 7;

  /// `HH:mm:ss` for the `time` column.
  String get timeValue {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(hour)}:${two(minute)}:00';
  }

  /// Minutes since midnight — to sort by time of day.
  int get minuteOfDay => hour * 60 + minute;

  bool isScheduledOn(DateTime day) => active && days.contains(day.weekday);

  /// The dose time on [day].
  DateTime at(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  static List<int> normalizeDays(Iterable<int> days) =>
      ({...days.where((d) => d >= 1 && d <= 7)}.toList()..sort());

  factory Reminder.fromJson(Map<String, dynamic> m) {
    final parts = (m['time'] as String? ?? '0:0').split(':');
    return Reminder(
      id: m['id'] as String,
      memberId: m['member_id'] as String?,
      name: m['name'] as String,
      dose: m['dose'] as String?,
      hour: int.tryParse(parts[0]) ?? 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      days: normalizeDays([
        for (final d in (m['days'] as List? ?? allWeekdays)) (d as num).toInt(),
      ]),
      active: m['active'] as bool? ?? true,
      createdAt: _time(m['created_at']),
    );
  }

  /// Insert / update payload (no `id`, `user_id`, `created_at`).
  Map<String, dynamic> toRow() => {
    'member_id': memberId,
    'name': name.trim(),
    'dose': (dose?.trim().isEmpty ?? true) ? null : dose!.trim(),
    'time': timeValue,
    'days': days,
    'active': active,
  };

  /// For the fake store.
  Map<String, dynamic> toJson() => {
    'id': id,
    ...toRow(),
    'created_at': createdAt?.toUtc().toIso8601String(),
  };

  Reminder copyWith({
    String? id,
    String? name,
    String? dose,
    int? hour,
    int? minute,
    List<int>? days,
    bool? active,
    DateTime? createdAt,
    bool clearMember = false,
    String? memberId,
  }) => Reminder(
    id: id ?? this.id,
    memberId: clearMember ? null : memberId ?? this.memberId,
    name: name ?? this.name,
    dose: dose ?? this.dose,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    days: days == null ? this.days : normalizeDays(days),
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
  );
}

/// A row of `reminder_logs`: the dose of [reminderId] was taken at
/// [takenAt]. It belongs to the dose of the same local date.
class ReminderLog {
  const ReminderLog({
    required this.id,
    required this.reminderId,
    required this.takenAt,
  });

  final String id;
  final String reminderId;
  final DateTime takenAt;

  factory ReminderLog.fromJson(Map<String, dynamic> m) => ReminderLog(
    id: m['id'] as String,
    reminderId: m['reminder_id'] as String,
    takenAt: _time(m['taken_at']) ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reminder_id': reminderId,
    'taken_at': takenAt.toUtc().toIso8601String(),
  };
}

enum DoseStatus {
  /// Logged as taken.
  taken,

  /// Time has come, within [doseGrace] — «Ichdim» is highlighted.
  due,

  /// Later today / in the future.
  upcoming,

  /// More than [doseGrace] late and not taken.
  missed,
}

/// How long after its time a dose still counts as «due», not «missed».
const doseGrace = Duration(hours: 2);

/// One scheduled intake: [reminder] on a day at [scheduledAt].
class Dose {
  const Dose({required this.reminder, required this.scheduledAt, this.log});

  final Reminder reminder;
  final DateTime scheduledAt;

  /// The log of this dose, if taken.
  final ReminderLog? log;

  bool get taken => log != null;

  DoseStatus status(DateTime now) {
    if (log != null) return DoseStatus.taken;
    if (now.isBefore(scheduledAt)) return DoseStatus.upcoming;
    if (now.isBefore(scheduledAt.add(doseGrace))) return DoseStatus.due;
    return DoseStatus.missed;
  }
}
