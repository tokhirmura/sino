import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/user.dart';
import '../data/family_care_repository.dart';

/// A dose counts as missed this long after its time without a mark.
const missedAfter = Duration(minutes: 30);

/// One scheduled dose of today.
class CareDose {
  const CareDose({
    required this.name,
    required this.at,
    required this.taken,
    this.dose,
  });

  final String name;
  final String? dose;
  final DateTime at;
  final bool taken;

  /// Not marked [missedAfter] after its time.
  bool missedAt(DateTime now) => !taken && now.isAfter(at.add(missedAfter));
}

/// A family member's day: doses, the next visit and an active reservation.
class MemberCare {
  const MemberCare({
    required this.member,
    this.doses = const [],
    this.visit,
    this.reservation,
  });

  final FamilyMember member;

  /// Today's doses by time.
  final List<CareDose> doses;
  final CareVisit? visit;
  final CareReservation? reservation;

  int get taken => doses.where((d) => d.taken).length;
  int get total => doses.length;

  List<CareDose> missedAt(DateTime now) => [
    for (final d in doses)
      if (d.missedAt(now)) d,
  ];

  /// Has medicines today and none of them is missed so far.
  bool onTrackAt(DateTime now) => total > 0 && missedAt(now).isEmpty;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Combines core family members with today's rows. Members keep their
/// order; a missed dose doesn't reorder anything (the card shows it).
List<MemberCare> buildFamilyCare(
  List<FamilyMember> members,
  FamilyCareRaw raw,
  DateTime now,
) {
  final today = _dateOnly(now);
  final takenIds = {
    for (final l in raw.logs)
      if (_dateOnly(l.takenAt) == today) l.reminderId,
  };
  return [
    for (final m in members)
      MemberCare(
        member: m,
        doses: [
          for (final r in raw.reminders)
            if (r.memberId == m.id &&
                r.active &&
                r.days.contains(today.weekday) &&
                (r.since == null || !today.isBefore(r.since!)))
              CareDose(
                name: r.name,
                dose: r.dose,
                at: today.add(Duration(minutes: r.minutes)),
                taken: takenIds.contains(r.id),
              ),
        ]..sort((a, b) => a.at.compareTo(b.at)),
        visit: _first(raw.visits.where((v) => v.memberId == m.id)),
        reservation: _first(raw.reservations.where((r) => r.memberId == m.id)),
      ),
  ];
}

T? _first<T>(Iterable<T> it) => it.isEmpty ? null : it.first;

/// For the home card: «3 kishidan 2 nafari dorini ichdi».
class FamilySummary {
  const FamilySummary({
    required this.members,
    required this.withMedicines,
    required this.onTrack,
    required this.missed,
  });

  /// Family members in total.
  final int members;

  /// Members with medicines today.
  final int withMedicines;

  /// Of them — nothing missed so far.
  final int onTrack;

  /// Members with a missed dose.
  final List<MemberCare> missed;
}

FamilySummary summarizeFamily(List<MemberCare> care, DateTime now) {
  final withMeds = care.where((c) => c.total > 0).toList();
  return FamilySummary(
    members: care.length,
    withMedicines: withMeds.length,
    onTrack: withMeds.where((c) => c.onTrackAt(now)).length,
    missed: [
      for (final c in withMeds)
        if (c.missedAt(now).isNotEmpty) c,
    ],
  );
}

/// «Now» for the family screen (tests override it).
final familyClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Today's rows. Reloaded when the family changes (e.g. demo data seeded
/// in the profile) and each time `/family` opens.
final familyCareRawProvider = FutureProvider<FamilyCareRaw>((ref) {
  ref.watch(familyMembersProvider);
  return ref
      .watch(familyCareRepositoryProvider)
      .load(ref.watch(familyClockProvider)());
});

/// Every family member with today's care.
final familyCareProvider = FutureProvider<List<MemberCare>>((ref) async {
  final members = await ref.watch(familyMembersProvider.future);
  if (members.isEmpty) return const [];
  final raw = await ref.watch(familyCareRawProvider.future);
  return buildFamilyCare(members, raw, ref.watch(familyClockProvider)());
});

final familySummaryProvider = FutureProvider<FamilySummary>((ref) async {
  final care = await ref.watch(familyCareProvider.future);
  return summarizeFamily(care, ref.watch(familyClockProvider)());
});

/// Opens the dialer (`tel:`). Tests override it.
final dialerProvider = Provider<Future<bool> Function(String phone)>(
  (_) =>
      (phone) => launchUrl(Uri(scheme: 'tel', path: phone)),
);
