/// Models of the doctors feature (tables `doctors`, `appointments`).
/// Hand-written `fromJson`/`toJson`, no codegen.
library;

DateTime? _time(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

/// Slugs used in `doctors.specialty` (Uzbek Latin, like
/// `family_members.relation`; labels uz/ru/en live in the UI). An unknown
/// slug from the database is kept and shown as is.
const doctorSpecialties = [
  'terapevt',
  'pediatr',
  'kardiolog',
  'nevrolog',
  'dermatolog',
  'ginekolog',
  'lor',
  'oftalmolog',
  'stomatolog',
  'endokrinolog',
  'gastroenterolog',
  'psixolog',
];

/// A row of the `doctors` catalog.
class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    this.slug,
    this.years,
    this.rating,
    this.priceUzs,
    this.clinic,
    this.online = false,
  });

  final String id;

  /// Asset-only readable id; `null` for rows from Supabase.
  final String? slug;
  final String name;

  /// One of [doctorSpecialties] (or an unknown slug).
  final String specialty;

  /// Years of experience.
  final int? years;
  final double? rating;

  /// Visit price; `0` — free (state polyclinic).
  final int? priceUzs;
  final String? clinic;

  /// Also takes online (video) consultations.
  final bool online;

  bool get isFree => priceUzs == 0;

  factory Doctor.fromJson(Map<String, dynamic> m) => Doctor(
    id: m['id'] as String,
    slug: m['slug'] as String?,
    name: m['name'] as String,
    specialty: m['specialty'] as String,
    years: (m['years'] as num?)?.toInt(),
    rating: (m['rating'] as num?)?.toDouble(),
    priceUzs: (m['price_uzs'] as num?)?.toInt(),
    clinic: m['clinic'] as String?,
    online: m['online'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (slug != null) 'slug': slug,
    'name': name,
    'specialty': specialty,
    'years': years,
    'rating': rating,
    'price_uzs': priceUzs,
    'clinic': clinic,
    'online': online,
  };
}

enum AppointmentStatus {
  booked,
  done,
  cancelled;

  static AppointmentStatus fromName(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => booked);
}

/// A row of `appointments`, with the joined [doctor]
/// (`select('*, doctors(*)')`).
class Appointment {
  const Appointment({
    required this.id,
    required this.doctorId,
    required this.startsAt,
    this.memberId,
    this.online = false,
    this.status = AppointmentStatus.booked,
    this.createdAt,
    this.doctor,
  });

  final String id;
  final String doctorId;

  /// `family_members.id`; `null` = for the user.
  final String? memberId;

  /// Local time.
  final DateTime startsAt;
  final bool online;
  final AppointmentStatus status;
  final DateTime? createdAt;
  final Doctor? doctor;

  /// Booked and still ahead.
  bool isUpcoming(DateTime now) =>
      status == AppointmentStatus.booked && startsAt.isAfter(now);

  /// Booked but its time has passed (the clinic hasn't marked it done).
  bool isPast(DateTime now) =>
      status != AppointmentStatus.cancelled && !startsAt.isAfter(now);

  factory Appointment.fromJson(Map<String, dynamic> m) => Appointment(
    id: m['id'] as String,
    doctorId: m['doctor_id'] as String,
    memberId: m['member_id'] as String?,
    startsAt: _time(m['starts_at'])!,
    online: m['online'] as bool? ?? false,
    status: AppointmentStatus.fromName(m['status'] as String?),
    createdAt: _time(m['created_at']),
    doctor: m['doctors'] is Map
        ? Doctor.fromJson(Map<String, dynamic>.from(m['doctors'] as Map))
        : null,
  );

  /// For the fake store (no join).
  Map<String, dynamic> toJson() => {
    'id': id,
    'doctor_id': doctorId,
    'member_id': memberId,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'online': online,
    'status': status.name,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };

  Appointment copyWith({AppointmentStatus? status, Doctor? doctor}) =>
      Appointment(
        id: id,
        doctorId: doctorId,
        memberId: memberId,
        startsAt: startsAt,
        online: online,
        status: status ?? this.status,
        createdAt: createdAt,
        doctor: doctor ?? this.doctor,
      );
}
