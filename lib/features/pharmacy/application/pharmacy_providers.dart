import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/backend/backend.dart';
import '../data/location_repository.dart';
import '../data/models.dart';
import '../data/pharmacy_repository.dart';
import 'write_queue.dart';

// ---------------------------------------------------------------------------
// Catalog
// ---------------------------------------------------------------------------

/// Whole `medicines` catalog, sorted by name.
final medicinesCatalogProvider = FutureProvider<List<Medicine>>(
  (ref) => ref.watch(pharmacyRepositoryProvider).medicines(),
);

final medicinesByIdProvider = FutureProvider<Map<String, Medicine>>((
  ref,
) async {
  final list = await ref.watch(medicinesCatalogProvider.future);
  return {for (final m in list) m.id: m};
});

/// All pharmacies, sorted by name.
final pharmaciesProvider = FutureProvider<List<Pharmacy>>(
  (ref) => ref.watch(pharmacyRepositoryProvider).pharmacies(),
);

final pharmaciesByIdProvider = FutureProvider<Map<String, Pharmacy>>((
  ref,
) async {
  final list = await ref.watch(pharmaciesProvider.future);
  return {for (final p in list) p.id: p};
});

/// Search results for a query (empty query → whole catalog).
/// Key — the trimmed query, so each keystroke is its own cache entry.
final medicineSearchProvider = FutureProvider.family<List<Medicine>, String>((
  ref,
  query,
) async {
  final list = await ref.watch(medicinesCatalogProvider.future);
  return searchMedicines(list, query);
});

/// Medicine by scanned barcode; `null` when it is not in the catalog.
final medicineByBarcodeProvider = FutureProvider.family<Medicine?, String>(
  (ref, code) => ref.watch(pharmacyRepositoryProvider).findByBarcode(code),
);

/// Generic substitutes of a medicine: ids listed in `medicines.analogs`
/// plus any other catalog row with the same active ingredient (rows added
/// to the database later may lack the list). Cheapest first.
final analogsProvider = FutureProvider.family<List<Medicine>, String>((
  ref,
  medicineId,
) async {
  final byId = await ref.watch(medicinesByIdProvider.future);
  return analogsOf(byId, medicineId);
});

List<Medicine> analogsOf(Map<String, Medicine> byId, String medicineId) {
  final m = byId[medicineId];
  if (m == null) return const [];
  final ingredient = m.ingredient?.trim().toLowerCase();
  final ids = <String>{
    ...m.analogs,
    if (ingredient != null && ingredient.isNotEmpty)
      for (final o in byId.values)
        if (o.ingredient?.trim().toLowerCase() == ingredient) o.id,
  }..remove(medicineId);
  return [
    for (final id in ids)
      if (byId[id] != null) byId[id]!,
  ]..sort((a, b) => (a.priceUzs ?? 0).compareTo(b.priceUzs ?? 0));
}

// ---------------------------------------------------------------------------
// Location, offers and the map
// ---------------------------------------------------------------------------

/// The user's position (`null` = unknown). Offers don't wait for it: they
/// are shown by price first and get distances once it arrives.
final userLocationProvider = FutureProvider<LatLng?>(
  (ref) => ref.watch(userLocationRepositoryProvider).current(),
);

double distanceKm(LatLng a, LatLng b) => const Distance().distance(a, b) / 1000;

/// One pharmacy's price of one medicine.
class StockOffer {
  const StockOffer({
    required this.medicine,
    required this.pharmacy,
    required this.stock,
    this.distanceKm,
  });

  final Medicine medicine;
  final Pharmacy pharmacy;
  final StockItem stock;

  /// `null` while the location is unknown.
  final double? distanceKm;

  bool get inStock => stock.inStock;
  int get priceUzs => stock.priceUzs;
}

enum OfferSort { price, distance }

/// In-stock offers first, then by [sort] (distance falls back to price
/// while the location is unknown).
List<StockOffer> sortOffers(List<StockOffer> offers, OfferSort sort) {
  int byPrice(StockOffer a, StockOffer b) => a.priceUzs.compareTo(b.priceUzs);
  int byDistance(StockOffer a, StockOffer b) {
    final da = a.distanceKm, db = b.distanceKm;
    if (da == null || db == null) return byPrice(a, b);
    final c = da.compareTo(db);
    return c != 0 ? c : byPrice(a, b);
  }

  return [...offers]..sort((a, b) {
    if (a.inStock != b.inStock) return a.inStock ? -1 : 1;
    return sort == OfferSort.price ? byPrice(a, b) : byDistance(a, b);
  });
}

/// Every pharmacy's offer of a medicine (also out of stock — shown greyed
/// out), sorted by price.
final medicineOffersProvider = FutureProvider.family<List<StockOffer>, String>((
  ref,
  medicineId,
) async {
  final repo = ref.watch(pharmacyRepositoryProvider);
  final here = ref.watch(userLocationProvider).value;
  final medsF = ref.watch(medicinesByIdProvider.future);
  final phsF = ref.watch(pharmaciesByIdProvider.future);
  final stock = await repo.stockFor(medicineId);
  final meds = await medsF;
  final phs = await phsF;
  final medicine = meds[medicineId];
  if (medicine == null) return const [];
  final offers = <StockOffer>[];
  for (final s in stock) {
    final p = s.pharmacy ?? phs[s.pharmacyId];
    if (p == null) continue;
    offers.add(
      StockOffer(
        medicine: medicine,
        pharmacy: p,
        stock: s,
        distanceKm: here == null
            ? null
            : distanceKm(here, LatLng(p.lat, p.lng)),
      ),
    );
  }
  return sortOffers(offers, OfferSort.price);
});

/// The cheapest in-stock price of a medicine (`null` — nowhere in stock).
final bestPriceProvider = FutureProvider.family<int?, String>((
  ref,
  medicineId,
) async {
  final offers = await ref.watch(medicineOffersProvider(medicineId).future);
  final inStock = [
    for (final o in offers)
      if (o.inStock) o.priceUzs,
  ];
  return inStock.isEmpty ? null : inStock.reduce((a, b) => a < b ? a : b);
});

class NearbyPharmacy {
  const NearbyPharmacy(this.pharmacy, this.distanceKm);

  final Pharmacy pharmacy;
  final double? distanceKm;

  LatLng get point => LatLng(pharmacy.lat, pharmacy.lng);
}

/// Pharmacies for the map / list, nearest first once the location is known.
final nearbyPharmaciesProvider = FutureProvider<List<NearbyPharmacy>>((
  ref,
) async {
  final here = ref.watch(userLocationProvider).value;
  final list = await ref.watch(pharmaciesProvider.future);
  final out = [
    for (final p in list)
      NearbyPharmacy(
        p,
        here == null ? null : distanceKm(here, LatLng(p.lat, p.lng)),
      ),
  ];
  if (here != null) {
    out.sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
  }
  return out;
});

// ---------------------------------------------------------------------------
// Reservations
// ---------------------------------------------------------------------------

enum ReservationProblem {
  /// Prescription-only medicine without a prescription photo.
  rxRequired,

  /// The pharmacy has none left.
  outOfStock,

  /// The same medicine is already reserved there (for the same person).
  alreadyActive,

  /// Already picked up or cancelled.
  notCancellable,
}

class ReservationException implements Exception {
  const ReservationException(this.problem);

  final ReservationProblem problem;

  @override
  String toString() => 'ReservationException(${problem.name})';
}

/// The user's reservations, newest first, live (realtime / fake pharmacy),
/// with optimistic reserve / cancel: the UI changes at once, a failed write
/// rolls back and rethrows.
class ReservationsNotifier extends StreamNotifier<List<Reservation>> {
  final _queue = WriteQueue();

  PharmacyRepository get _repo => ref.read(pharmacyRepositoryProvider);

  List<Reservation> get _current => state.value ?? const [];

  Map<String, Medicine> _meds = const {};
  Map<String, Pharmacy> _phs = const {};

  @override
  Stream<List<Reservation>> build() async* {
    ref.watch(authStateProvider);
    final repo = ref.watch(pharmacyRepositoryProvider);
    final medsF = ref.watch(medicinesByIdProvider.future);
    final phsF = ref.watch(pharmaciesByIdProvider.future);
    _meds = await medsF;
    _phs = await phsF;
    yield* repo.watchReservations().map(
      (list) => [for (final r in list) r.resolve(_meds, _phs)],
    );
  }

  Future<void> _ready() async {
    final err = state.error;
    if (state.hasError && err != null) {
      Error.throwWithStackTrace(err, state.stackTrace ?? StackTrace.current);
    }
    if (state.isLoading) await future;
  }

  /// Reserves [offer] (for a family member when [forMemberId] is set).
  /// Throws [ReservationException] before any write when not allowed.
  Future<Reservation> reserve(
    StockOffer offer, {
    String? forMemberId,
    bool rxAttached = false,
  }) async {
    if (offer.medicine.rx && !rxAttached) {
      throw const ReservationException(ReservationProblem.rxRequired);
    }
    if (!offer.inStock) {
      throw const ReservationException(ReservationProblem.outOfStock);
    }
    await _ready();
    final duplicate = _current.any(
      (r) =>
          r.status.isActive &&
          r.medicineId == offer.medicine.id &&
          r.pharmacyId == offer.pharmacy.id &&
          r.forMemberId == forMemberId,
    );
    if (duplicate) {
      throw const ReservationException(ReservationProblem.alreadyActive);
    }
    final temp = Reservation(
      id: newPendingId(),
      medicineId: offer.medicine.id,
      pharmacyId: offer.pharmacy.id,
      forMemberId: forMemberId,
      rxAttached: rxAttached,
      createdAt: DateTime.now(),
      medicine: offer.medicine,
      pharmacy: offer.pharmacy,
    );
    if (ref.mounted) state = AsyncData([temp, ..._current]);
    try {
      final saved = (await _queue.run(
        () => _repo.reserve(
          medicineId: temp.medicineId,
          pharmacyId: temp.pharmacyId,
          forMemberId: forMemberId,
          rxAttached: rxAttached,
        ),
      )).resolve(_meds, _phs);
      if (ref.mounted) {
        // The live stream may already have delivered the saved row.
        state = AsyncData([
          saved,
          for (final r in _current)
            if (r.id != temp.id && r.id != saved.id) r,
        ]);
      }
      return saved;
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData([
          for (final r in _current)
            if (r.id != temp.id) r,
        ]);
      }
      rethrow;
    }
  }

  Future<void> cancel(String id) async {
    await _ready();
    Reservation? old;
    for (final r in _current) {
      if (r.id == id) old = r;
    }
    if (old == null || isPendingId(id)) return;
    if (!old.status.isActive) {
      throw const ReservationException(ReservationProblem.notCancellable);
    }
    final before = old.status;
    _setStatus(id, ReservationStatus.cancelled);
    try {
      await _queue.run(() => _repo.cancelReservation(id));
    } catch (_) {
      if (ref.mounted) _setStatus(id, before);
      rethrow;
    }
  }

  void _setStatus(String id, ReservationStatus status) {
    if (!ref.mounted) return;
    state = AsyncData([
      for (final r in _current) r.id == id ? r.copyWith(status: status) : r,
    ]);
  }
}

final reservationsProvider =
    StreamNotifierProvider<ReservationsNotifier, List<Reservation>>(
      ReservationsNotifier.new,
    );

/// Reservations waiting to be picked up (`pending` / `ready`).
final activeReservationsProvider = Provider<AsyncValue<List<Reservation>>>(
  (ref) => ref
      .watch(reservationsProvider)
      .whenData(
        (l) => [
          for (final r in l)
            if (r.status.isActive) r,
        ],
      ),
);
