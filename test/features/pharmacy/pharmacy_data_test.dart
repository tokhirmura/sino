import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/features/pharmacy/application/pharmacy_providers.dart';
import 'package:sino/features/pharmacy/data/models.dart';
import 'package:sino/features/pharmacy/data/pharmacy_repository.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

List<Map<String, dynamic>> _asset(String name) => [
  for (final r
      in jsonDecode(File('assets/pharmacy/$name').readAsStringSync()) as List)
    r as Map<String, dynamic>,
];

bool _validEan13(String code) {
  if (!RegExp(r'^\d{13}$').hasMatch(code)) return false;
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(code[i]) * (i.isEven ? 1 : 3);
  }
  return (10 - sum % 10) % 10 == int.parse(code[12]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final medicines = _asset('medicines.json');
  final pharmacies = _asset('pharmacies.json');
  final stock = _asset('pharmacy_stock.json');
  final medIds = {for (final m in medicines) m['id']};
  final phIds = {for (final p in pharmacies) p['id']};

  group('medicines.json', () {
    test('unique uuid ids, slugs and valid unique EAN-13 barcodes', () {
      expect(medicines.length, greaterThanOrEqualTo(30));
      expect(medIds, hasLength(medicines.length));
      expect({
        for (final m in medicines) m['slug'],
      }, hasLength(medicines.length));
      expect({
        for (final m in medicines) m['barcode'],
      }, hasLength(medicines.length));
      for (final m in medicines) {
        expect(m['id'], matches(_uuid));
        expect(_validEan13(m['barcode'] as String), isTrue, reason: m['slug']);
      }
    });

    test('only table columns, known form/category, texts in 3 languages', () {
      const columns = {
        'id', 'slug', 'name', 'ingredient', 'form', 'category', 'rx', //
        'price_uzs', 'barcode', 'description', 'warning', 'analogs',
      };
      for (final m in medicines) {
        expect(columns.containsAll(m.keys), isTrue, reason: '${m.keys}');
        expect(medicineForms, contains(m['form']), reason: m['slug']);
        expect(medicineCategories, contains(m['category']), reason: m['slug']);
        expect(m['price_uzs'] as int, greaterThan(0));
        for (final key in ['description', 'warning']) {
          final texts = m[key] as Map;
          for (final l in ['uz', 'ru', 'en']) {
            expect(
              (texts[l] as String).trim(),
              isNotEmpty,
              reason: '${m['slug']}.$key.$l',
            );
          }
        }
      }
    });

    test('analogs: existing ids, same ingredient, symmetric, not self', () {
      final byId = {for (final m in medicines) m['id']: m};
      for (final m in medicines) {
        for (final a in m['analogs'] as List) {
          expect(a, isNot(m['id']));
          expect(byId[a], isNotNull, reason: '${m['slug']} → $a');
          expect(byId[a]!['ingredient'], m['ingredient']);
          expect(byId[a]!['analogs'] as List, contains(m['id']));
        }
        final sameIngredient = medicines.where(
          (o) => o['id'] != m['id'] && o['ingredient'] == m['ingredient'],
        );
        expect((m['analogs'] as List).toSet(), {
          for (final o in sameIngredient) o['id'],
        });
      }
    });

    test('the assistant’s pharmacy queries find medicines', () {
      final list = [for (final m in medicines) Medicine.fromJson(m)];
      for (final q in ['ibuprofen', 'paracetamol']) {
        expect(searchMedicines(list, q), isNotEmpty, reason: q);
      }
    });
  });

  group('pharmacies.json and pharmacy_stock.json', () {
    test('pharmacies have uuid ids and coordinates in Tashkent', () {
      expect(phIds, hasLength(pharmacies.length));
      for (final p in pharmacies) {
        expect(p['id'], matches(_uuid));
        expect(p['lat'] as num, inInclusiveRange(41.15, 41.45));
        expect(p['lng'] as num, inInclusiveRange(69.1, 69.45));
      }
    });

    test('stock references the catalog, one row per pharmacy+medicine', () {
      final pairs = <String>{};
      for (final s in stock) {
        expect(s['id'], matches(_uuid));
        expect(medIds, contains(s['medicine_id']));
        expect(phIds, contains(s['pharmacy_id']));
        expect(s['price_uzs'] as int, greaterThan(0));
        expect(s['qty'] as int, greaterThanOrEqualTo(0));
        expect(pairs.add('${s['pharmacy_id']}|${s['medicine_id']}'), isTrue);
      }
      expect({for (final s in stock) s['id']}, hasLength(stock.length));
    });

    test('every medicine is in stock somewhere; some rows are sold out', () {
      final available = {
        for (final s in stock)
          if ((s['qty'] as int) > 0) s['medicine_id'],
      };
      expect(available, medIds);
      expect(stock.any((s) => s['qty'] == 0), isTrue);
    });
  });

  group('models', () {
    test('StockItem parses the pharmacies join', () {
      final s = StockItem.fromJson({
        'id': 's1',
        'pharmacy_id': 'p1',
        'medicine_id': 'm1',
        'price_uzs': 12000,
        'qty': 0,
        'pharmacies': {
          'id': 'p1',
          'name': 'Shifo',
          'lat': 41.3,
          'lng': 69.2,
          'open24': true,
          'rating': 4.5,
        },
      });
      expect(s.inStock, isFalse);
      expect(s.pharmacy!.name, 'Shifo');
      expect(s.pharmacy!.open24, isTrue);
    });

    test('Reservation round-trips and resolves the catalog', () {
      final r = Reservation.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'medicine_id': 'm1',
        'pharmacy_id': 'p1',
        'for_member_id': null,
        'status': 'ready',
        'rx_attached': true,
        'created_at': '2026-11-17T08:00:00+00:00',
      });
      expect(r.status, ReservationStatus.ready);
      expect(r.status.isActive, isTrue);
      expect(r.createdAt!.isUtc, isFalse);
      final back = Reservation.fromJson(r.toJson());
      expect(back.createdAt, r.createdAt);
      expect(back.rxAttached, isTrue);
      final resolved = r.resolve(
        {'m1': const Medicine(id: 'm1', name: 'X')},
        {'p1': const Pharmacy(id: 'p1', name: 'P', lat: 0, lng: 0)},
      );
      expect(resolved.medicine!.name, 'X');
      expect(resolved.pharmacy!.name, 'P');
      expect(ReservationStatus.fromName('weird'), ReservationStatus.pending);
    });
  });

  group('search and analogs', () {
    final list = [for (final m in medicines) Medicine.fromJson(m)];

    test('name matches come first', () {
      final r = searchMedicines(list, 'ibuprofen');
      expect(r.first.name, startsWith('Ibuprofen'));
      expect(r.map((m) => m.slug), containsAll(['nurofen', 'nurofen_kids']));
    });

    test('Cyrillic, apostrophes, symptoms and barcodes', () {
      expect(searchMedicines(list, 'ибупрофен').first.slug, 'ibuprofen');
      expect(
        searchMedicines(list, 'Faollashtirilgan komir').first.slug,
        'activated_charcoal',
      );
      final fever = searchMedicines(list, 'isitma').map((m) => m.slug);
      expect(fever, contains('paracetamol'));
      final code = list.firstWhere((m) => m.slug == 'smecta').barcode!;
      expect(searchMedicines(list, code).first.slug, 'smecta');
      expect(searchMedicines(list, '  '), hasLength(list.length));
    });

    test('analogs: same ingredient, cheapest first', () {
      final byId = {for (final m in list) m.id: m};
      final para = list.firstWhere((m) => m.slug == 'paracetamol');
      final a = analogsOf(byId, para.id);
      expect(a.map((m) => m.slug), [
        'paracetamol_syrup',
        'panadol',
        'efferalgan',
      ]);
      final suprastin = list.firstWhere((m) => m.slug == 'suprastin');
      expect(analogsOf(byId, suprastin.id), isEmpty);
    });

    test('offers: in stock first, then by price or distance', () {
      const med = Medicine(id: 'm', name: 'M');
      StockOffer offer(String id, int price, int qty, double? km) => StockOffer(
        medicine: med,
        pharmacy: Pharmacy(id: id, name: id, lat: 0, lng: 0),
        stock: StockItem(
          id: id,
          pharmacyId: id,
          medicineId: 'm',
          priceUzs: price,
          qty: qty,
        ),
        distanceKm: km,
      );
      final offers = [
        offer('far-cheap', 1000, 5, 9),
        offer('sold-out', 500, 0, 1),
        offer('near', 2000, 5, 1),
      ];
      expect(sortOffers(offers, OfferSort.price).map((o) => o.pharmacy.id), [
        'far-cheap',
        'near',
        'sold-out',
      ]);
      expect(sortOffers(offers, OfferSort.distance).map((o) => o.pharmacy.id), [
        'near',
        'far-cheap',
        'sold-out',
      ]);
      expect(
        distanceKm(
          const LatLng(41.3111, 69.2797),
          const LatLng(41.3111, 69.2797),
        ),
        0,
      );
    });
  });

  group('FakePharmacyRepository', () {
    late SharedPreferences prefs;
    final now = DateTime(2026, 11, 17, 12);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('catalog, barcode lookup and stock with pharmacies', () async {
      final repo = FakePharmacyRepository(prefs, now: now, readyAfter: null);
      final meds = await repo.medicines();
      expect(meds, hasLength(medicines.length));
      final nurofen = meds.firstWhere((m) => m.slug == 'nurofen');
      expect((await repo.findByBarcode(nurofen.barcode!))!.id, nurofen.id);
      expect(await repo.findByBarcode('0000000000000'), isNull);
      final rows = await repo.stockFor(nurofen.id);
      expect(rows, isNotEmpty);
      expect(rows.every((s) => s.pharmacy != null), isTrue);
    });

    test('demo reservations, reserve, cancel — persisted in prefs', () async {
      final repo = FakePharmacyRepository(prefs, now: now, readyAfter: null);
      final demo = await repo.reservations();
      expect(demo, hasLength(2));
      expect(demo.first.status, ReservationStatus.ready);
      expect(demo.last.forMemberId, 'fake-father');

      final meds = await repo.medicines();
      final phs = await repo.pharmacies();
      final r = await repo.reserve(
        medicineId: meds.first.id,
        pharmacyId: phs.first.id,
      );
      expect(r.status, ReservationStatus.pending);
      await repo.cancelReservation(r.id);

      final again = FakePharmacyRepository(prefs, now: now, readyAfter: null);
      final list = await again.reservations();
      expect(list, hasLength(3));
      expect(
        list.firstWhere((x) => x.id == r.id).status,
        ReservationStatus.cancelled,
      );
    });

    test('a pending reservation becomes ready after readyAfter', () async {
      final repo = FakePharmacyRepository(prefs, now: now, readyAfter: null);
      final meds = await repo.medicines();
      final phs = await repo.pharmacies();
      final r = await repo.reserve(
        medicineId: meds.first.id,
        pharmacyId: phs.first.id,
      );
      final later = FakePharmacyRepository(
        prefs,
        now: now.add(const Duration(seconds: 30)),
        readyAfter: const Duration(seconds: 20),
      );
      final list = await later.reservations();
      expect(
        list.firstWhere((x) => x.id == r.id).status,
        ReservationStatus.ready,
      );
    });

    test('watch emits now and after changes; timer moves to ready', () async {
      final repo = FakePharmacyRepository(
        prefs,
        readyAfter: const Duration(milliseconds: 50),
      );
      final meds = await repo.medicines();
      final phs = await repo.pharmacies();
      final seen = <List<Reservation>>[];
      final sub = repo.watchReservations().listen(seen.add);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(seen, hasLength(1));
      final r = await repo.reserve(
        medicineId: meds.first.id,
        pharmacyId: phs.first.id,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final last = seen.last.firstWhere((x) => x.id == r.id);
      expect(last.status, ReservationStatus.ready);
      await sub.cancel();
    });
  });
}
