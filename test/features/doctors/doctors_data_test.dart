import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/core/backend/backend.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/features/doctors/application/doctor_slots.dart';
import 'package:sino/features/doctors/application/doctors_providers.dart';
import 'package:sino/features/doctors/data/doctors_repository.dart';
import 'package:sino/features/doctors/data/models.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

class _GatedRepo extends FakeDoctorsRepository {
  _GatedRepo(super.prefs);

  Completer<void> gate = Completer<void>()..complete();
  bool fail = false;

  Future<void> _write() async {
    await gate.future;
    if (fail) throw Exception('network');
  }

  @override
  Future<Appointment> book({
    required String doctorId,
    required DateTime startsAt,
    String? memberId,
    bool online = false,
  }) async {
    await _write();
    return super.book(
      doctorId: doctorId,
      startsAt: startsAt,
      memberId: memberId,
      online: online,
    );
  }

  @override
  Future<void> cancel(String id) async {
    await _write();
    return super.cancel(id);
  }
}

const _doc = Doctor(id: 'd1', name: 'D', specialty: 'terapevt', online: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rows = [
    for (final r in jsonDecode(
      File('assets/pharmacy/doctors.json').readAsStringSync(),
    ) as List)
      r as Map<String, dynamic>,
  ];

  group('doctors.json', () {
    test('uuid ids, known specialty slugs, only table columns', () {
      const columns = {
        'id', 'slug', 'name', 'specialty', 'years', 'rating', //
        'price_uzs', 'clinic', 'online',
      };
      expect({for (final r in rows) r['id']}, hasLength(rows.length));
      for (final r in rows) {
        expect(r['id'], matches(_uuid));
        expect(doctorSpecialties, contains(r['specialty']), reason: r['slug']);
        expect(columns.containsAll(r.keys), isTrue, reason: '${r.keys}');
        expect(r['price_uzs'] as int, greaterThanOrEqualTo(0));
        expect(r['rating'] as num, inInclusiveRange(0, 5));
      }
      // Free state polyclinic doctors and online doctors are both present.
      expect(rows.any((r) => r['price_uzs'] == 0), isTrue);
      expect(rows.any((r) => r['online'] == true), isTrue);
    });
  });

  group('models and filter', () {
    test('Appointment parses the doctors join and local time', () {
      final a = Appointment.fromJson({
        'id': 'a1',
        'user_id': 'u1',
        'doctor_id': 'd1',
        'member_id': null,
        'starts_at': '2026-11-20T05:30:00+00:00',
        'online': true,
        'status': 'booked',
        'created_at': '2026-11-17T05:30:00+00:00',
        'doctors': _doc.toJson(),
      });
      expect(a.startsAt.isUtc, isFalse);
      expect(a.doctor!.specialty, 'terapevt');
      expect(Appointment.fromJson(a.toJson()).startsAt, a.startsAt);
      expect(AppointmentStatus.fromName(null), AppointmentStatus.booked);
    });

    test('filter by specialty, online and text', () {
      final list = [for (final r in rows) Doctor.fromJson(r)];
      final kardio = filterDoctors(list, specialty: 'kardiolog');
      expect(kardio, hasLength(2));
      expect(
        filterDoctors(list, onlineOnly: true).every((d) => d.online),
        isTrue,
      );
      expect(filterDoctors(list, query: 'ko‘z nuri').single.slug, 'mirzayeva');
      expect(filterDoctors(list, query: 'koz nuri').single.slug, 'mirzayeva');
      expect(filterDoctors(list), hasLength(list.length));
    });
  });

  group('slots', () {
    // Wednesday 2026-11-18; Sunday 2026-11-22.
    final wed = DateTime(2026, 11, 18);

    test('working hours without lunch, none on Sunday', () {
      final times = daySlotTimes(wed);
      expect(times.first, DateTime(2026, 11, 18, 9));
      expect(times.last, DateTime(2026, 11, 18, 16, 30));
      expect(times.any((t) => t.hour == 13), isFalse);
      expect(times, hasLength(14));
      expect(daySlotTimes(DateTime(2026, 11, 22)), isEmpty);
    });

    test('booking days: two weeks, working days only', () {
      final days = bookingDays(DateTime(2026, 11, 17, 18));
      expect(days.first, DateTime(2026, 11, 17));
      expect(days.any((d) => d.weekday == DateTime.sunday), isFalse);
      expect(days, hasLength(12));
    });

    test('busy slots are stable and about 30 %', () {
      final doctors = [for (final r in rows) r['id'] as String];
      var busy = 0, total = 0;
      for (final d in doctors) {
        for (final t in daySlotTimes(wed)) {
          expect(isBusySlot(d, t), isBusySlot(d, t));
          total++;
          if (isBusySlot(d, t)) busy++;
        }
      }
      expect(busy / total, inInclusiveRange(0.15, 0.45));
    });

    test('past, mine and clash', () {
      final now = DateTime(2026, 11, 18, 11, 10);
      final mine = Appointment(
        id: 'a',
        doctorId: 'd1',
        startsAt: DateTime(2026, 11, 18, 15),
      );
      final other = Appointment(
        id: 'b',
        doctorId: 'd2',
        startsAt: DateTime(2026, 11, 18, 16),
      );
      final cancelled = Appointment(
        id: 'c',
        doctorId: 'd1',
        startsAt: DateTime(2026, 11, 18, 16, 30),
        status: AppointmentStatus.cancelled,
      );
      final slots = {
        for (final s in slotsFor(_doc, wed, [mine, other, cancelled], now))
          s.at.hour * 60 + s.at.minute: s.state,
      };
      expect(slots[11 * 60], SlotState.past);
      expect(slots[15 * 60], SlotState.mine);
      expect(slots[16 * 60], SlotState.clash);
      expect(slots[16 * 60 + 30], isNot(SlotState.mine));
      // A family member is free when the user has another appointment.
      final forMother = slotsFor(
        _doc,
        wed,
        [other],
        now,
        memberId: 'fake-mother',
      ).firstWhere((s) => s.at.hour == 16 && s.at.minute == 0);
      expect(forMother.state, isNot(SlotState.clash));
    });
  });

  group('FakeDoctorsRepository', () {
    late SharedPreferences prefs;
    final now = DateTime(2026, 11, 17, 12);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('catalog best rated first; demo appointments with doctors', () async {
      final repo = FakeDoctorsRepository(prefs, now: now);
      final docs = await repo.doctors();
      expect(docs, hasLength(rows.length));
      expect(docs.first.rating, greaterThanOrEqualTo(docs.last.rating!));
      final appts = await repo.appointments();
      expect(appts, hasLength(3));
      expect(appts.first.status, AppointmentStatus.done);
      expect(appts.every((a) => a.doctor != null), isTrue);
      expect(appts[1].startsAt, DateTime(2026, 11, 19, 10, 30));
    });

    test('book and cancel persist', () async {
      final repo = FakeDoctorsRepository(prefs, now: now);
      final docs = await repo.doctors();
      final a = await repo.book(
        doctorId: docs.first.id,
        startsAt: DateTime(2026, 11, 20, 9),
        memberId: 'fake-daughter',
      );
      expect(a.doctor!.id, docs.first.id);
      await repo.cancel(a.id);
      final again = await FakeDoctorsRepository(prefs, now: now).appointments();
      final saved = again.firstWhere((x) => x.id == a.id);
      expect(saved.status, AppointmentStatus.cancelled);
      expect(saved.memberId, 'fake-daughter');
    });
  });

  group('providers', () {
    late ProviderContainer container;
    late _GatedRepo repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = _GatedRepo(prefs);
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          useFakeProvider.overrideWithValue(true),
          doctorsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.listen(appointmentsProvider, (_, _) {});
      container.listen(doctorsByIdProvider, (_, _) {});
    });

    AppointmentsNotifier notifier() =>
        container.read(appointmentsProvider.notifier);

    /// First free slot of [doctor] from tomorrow on.
    Future<DateTime> freeSlot(Doctor doctor) async {
      final appts = await container.read(appointmentsProvider.future);
      final now = DateTime.now();
      for (final day in bookingDays(now).skip(1)) {
        for (final s in slotsFor(doctor, day, appts, now)) {
          if (s.isFree) return s.at;
        }
      }
      throw StateError('no free slot');
    }

    test('specialties follow the canonical order', () async {
      final s = await container.read(specialtiesProvider.future);
      expect(s.first, 'terapevt');
      expect(s, hasLength(doctorSpecialties.length));
    });

    test('book is optimistic, then saved; slot becomes mine', () async {
      final docs = await container.read(doctorsCatalogProvider.future);
      final doc = docs.firstWhere((d) => d.slug == 'nazarov');
      final at = await freeSlot(doc);
      repo.gate = Completer<void>();
      final future = notifier().book(doc, at);
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(appointmentsProvider)
            .value!
            .any((a) => a.id.startsWith('pending-')),
        isTrue,
      );
      repo.gate.complete();
      final saved = await future;
      expect(saved.doctor!.id, doc.id);
      final upcoming = container.read(upcomingAppointmentsProvider).value!;
      expect(upcoming.map((a) => a.id), contains(saved.id));

      final day = DateTime(at.year, at.month, at.day);
      final slots = container
          .read(
            doctorSlotsProvider((doctorId: doc.id, day: day, memberId: null)),
          )
          .value!;
      expect(slots.firstWhere((s) => s.at == at).state, SlotState.mine);
      await expectLater(
        notifier().book(doc, at),
        throwsA(
          isA<AppointmentException>().having(
            (e) => e.problem,
            'problem',
            AppointmentProblem.slotUnavailable,
          ),
        ),
      );
    });

    test(
      'online only with online doctors; failed booking rolls back',
      () async {
        final docs = await container.read(doctorsCatalogProvider.future);
        final offline = docs.firstWhere((d) => !d.online);
        await expectLater(
          notifier().book(offline, await freeSlot(offline), online: true),
          throwsA(
            isA<AppointmentException>().having(
              (e) => e.problem,
              'problem',
              AppointmentProblem.onlineNotSupported,
            ),
          ),
        );
        repo.fail = true;
        final before = container.read(appointmentsProvider).value!.length;
        await expectLater(
          notifier().book(offline, await freeSlot(offline)),
          throwsException,
        );
        expect(container.read(appointmentsProvider).value!, hasLength(before));
      },
    );

    test('cancel: optimistic, rollback, only booked ones', () async {
      final appts = await container.read(appointmentsProvider.future);
      final booked = appts.firstWhere(
        (a) => a.status == AppointmentStatus.booked,
      );
      repo.fail = true;
      await expectLater(notifier().cancel(booked.id), throwsException);
      AppointmentStatus status() => container
          .read(appointmentsProvider)
          .value!
          .firstWhere((a) => a.id == booked.id)
          .status;
      expect(status(), AppointmentStatus.booked);
      repo.fail = false;
      await notifier().cancel(booked.id);
      expect(status(), AppointmentStatus.cancelled);
      await expectLater(
        notifier().cancel(booked.id),
        throwsA(isA<AppointmentException>()),
      );
      final past = container.read(pastAppointmentsProvider).value!;
      expect(past.map((a) => a.id), contains(booked.id));
    });
  });
}
