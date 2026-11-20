import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/core/backend/backend.dart';
import 'package:sino/core/storage/prefs.dart';
import 'package:sino/features/pharmacy/application/pharmacy_providers.dart';
import 'package:sino/features/pharmacy/data/models.dart';
import 'package:sino/features/pharmacy/data/pharmacy_repository.dart';

/// Fake repo whose writes wait for [gate] and fail when [fail] is set.
class _GatedRepo extends FakePharmacyRepository {
  _GatedRepo(super.prefs) : super(readyAfter: null);

  Completer<void> gate = Completer<void>()..complete();
  bool fail = false;

  Future<void> _write() async {
    await gate.future;
    if (fail) throw Exception('network');
  }

  @override
  Future<Reservation> reserve({
    required String medicineId,
    required String pharmacyId,
    String? forMemberId,
    bool rxAttached = false,
  }) async {
    await _write();
    return super.reserve(
      medicineId: medicineId,
      pharmacyId: pharmacyId,
      forMemberId: forMemberId,
      rxAttached: rxAttached,
    );
  }

  @override
  Future<void> cancelReservation(String id) async {
    await _write();
    return super.cancelReservation(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        pharmacyRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.listen(reservationsProvider, (_, _) {});
  });

  List<Reservation> current() => container.read(reservationsProvider).value!;

  ReservationsNotifier notifier() =>
      container.read(reservationsProvider.notifier);

  Future<StockOffer> offer(String slug, {bool inStock = true}) async {
    final meds = await container.read(medicinesCatalogProvider.future);
    final m = meds.firstWhere((x) => x.slug == slug);
    // Listen first: Riverpod pauses unlistened providers, and offers rebuild
    // when the location arrives.
    container.listen(medicineOffersProvider(m.id), (_, _) {});
    final offers = await container.read(medicineOffersProvider(m.id).future);
    return offers.firstWhere((o) => o.inStock == inStock);
  }

  test('loads demo reservations resolved with the catalog', () async {
    final list = await container.read(reservationsProvider.future);
    expect(list, hasLength(2));
    expect(list.first.medicine!.slug, 'ibuprofen');
    expect(list.first.pharmacy!.slug, 'shifo');
    final active = container.read(activeReservationsProvider).value!;
    expect(active, hasLength(1));
  });

  test('offers have distances in fake mode and are sorted', () async {
    await container.read(userLocationProvider.future);
    final o = await offer('paracetamol');
    expect(o.distanceKm, isNotNull);
    final best = await container.read(bestPriceProvider(o.medicine.id).future);
    expect(best, o.priceUzs);
  });

  test('reserve is optimistic, then replaced by the saved row', () async {
    await container.read(reservationsProvider.future);
    final o = await offer('loratadine');
    repo.gate = Completer<void>();
    final future = notifier().reserve(o);
    await Future<void>.delayed(Duration.zero);
    expect(current().first.id, startsWith('pending-'));
    expect(current().first.medicine!.slug, 'loratadine');
    repo.gate.complete();
    final saved = await future;
    expect(saved.id, startsWith('fake-res-'));
    expect(current().where((r) => r.medicineId == o.medicine.id), hasLength(1));
    expect(current().any((r) => r.id.startsWith('pending-')), isFalse);
  });

  test('failed reserve rolls back and rethrows', () async {
    await container.read(reservationsProvider.future);
    final o = await offer('loratadine');
    repo.fail = true;
    await expectLater(notifier().reserve(o), throwsException);
    expect(current(), hasLength(2));
  });

  test('rules: prescription, stock, duplicates', () async {
    await container.read(reservationsProvider.future);
    final rx = await offer('amoxicillin');
    await expectLater(
      notifier().reserve(rx),
      throwsA(
        isA<ReservationException>().having(
          (e) => e.problem,
          'problem',
          ReservationProblem.rxRequired,
        ),
      ),
    );
    await notifier().reserve(rx, rxAttached: true);

    final soldOut = await _soldOut(container);
    await expectLater(
      notifier().reserve(soldOut),
      throwsA(isA<ReservationException>()),
    );

    final ibu = await offer('ibuprofen');
    await notifier().reserve(ibu);
    await expectLater(
      notifier().reserve(ibu),
      throwsA(
        isA<ReservationException>().having(
          (e) => e.problem,
          'problem',
          ReservationProblem.alreadyActive,
        ),
      ),
    );
    // Same medicine for a family member is a separate reservation.
    await notifier().reserve(ibu, forMemberId: 'fake-mother');
  });

  test('cancel is optimistic and rolls back on failure', () async {
    final list = await container.read(reservationsProvider.future);
    final ready = list.firstWhere((r) => r.status == ReservationStatus.ready);
    repo.fail = true;
    await expectLater(notifier().cancel(ready.id), throwsException);
    expect(
      current().firstWhere((r) => r.id == ready.id).status,
      ReservationStatus.ready,
    );
    repo.fail = false;
    await notifier().cancel(ready.id);
    expect(
      current().firstWhere((r) => r.id == ready.id).status,
      ReservationStatus.cancelled,
    );
    final picked = current().firstWhere(
      (r) => r.status == ReservationStatus.picked,
    );
    await expectLater(
      notifier().cancel(picked.id),
      throwsA(isA<ReservationException>()),
    );
  });
}

/// Any sold-out offer from the catalog.
Future<StockOffer> _soldOut(ProviderContainer c) async {
  final meds = await c.read(medicinesCatalogProvider.future);
  for (final m in meds) {
    c.listen(medicineOffersProvider(m.id), (_, _) {});
    final offers = await c.read(medicineOffersProvider(m.id).future);
    for (final o in offers) {
      if (!o.inStock && !o.medicine.rx) return o;
    }
  }
  throw StateError('no sold-out offer in the catalog');
}
