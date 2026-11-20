import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';
import '../../../core/storage/prefs.dart';
import 'models.dart';

/// Medicine catalog, pharmacies with stock and the user's reservations.
abstract class PharmacyRepository {
  /// Whole `medicines` catalog, sorted by name (small — searched on device).
  Future<List<Medicine>> medicines();

  /// Medicine by EAN-13 barcode (scanner), `null` if unknown.
  Future<Medicine?> findByBarcode(String barcode);

  /// All pharmacies, sorted by name.
  Future<List<Pharmacy>> pharmacies();

  /// Stock rows of one medicine in every pharmacy (with `pharmacy` joined),
  /// including rows with `qty == 0`.
  Future<List<StockItem>> stockFor(String medicineId);

  /// The user's reservations, newest first.
  Future<List<Reservation>> reservations();

  /// [reservations] now and on every change (realtime: the pharmacy moves
  /// `pending → ready`).
  Stream<List<Reservation>> watchReservations();

  Future<Reservation> reserve({
    required String medicineId,
    required String pharmacyId,
    String? forMemberId,
    bool rxAttached = false,
  });

  Future<void> cancelReservation(String id);
}

/// Search in the catalog: case-insensitive over the trade name, active
/// ingredient, slug, barcode and description (so symptoms like «isitma» /
/// «температура» work too). Apostrophes are ignored and Cyrillic is
/// transliterated, so «ибупрофен» finds Ibuprofen. Best matches first:
/// name prefix → name → ingredient → description.
List<Medicine> searchMedicines(List<Medicine> medicines, String query) {
  final q = normalizeMedicineText(query);
  if (q.isEmpty) return medicines;
  final digits = query.replaceAll(RegExp(r'\D'), '');
  final ranked = <(int, Medicine)>[];
  for (final m in medicines) {
    final name = normalizeMedicineText(m.name);
    final other = [
      m.ingredient,
      m.slug?.replaceAll('_', ' '),
    ].whereType<String>().map(normalizeMedicineText);
    final int? rank;
    if (name.startsWith(q) || name.split(' ').any((w) => w.startsWith(q))) {
      rank = 0;
    } else if (name.contains(q)) {
      rank = 1;
    } else if (other.any((s) => s.contains(q))) {
      rank = 2;
    } else if (digits.length >= 4 && (m.barcode ?? '').contains(digits)) {
      rank = 2;
    } else if (m.description.values.any(
      (v) => normalizeMedicineText('$v').contains(q),
    )) {
      rank = 3;
    } else {
      rank = null;
    }
    if (rank != null) ranked.add((rank, m));
  }
  ranked.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final r in ranked) r.$2];
}

const _cyrillic = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e', //
  'ж': 'j', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
  'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
  'ф': 'f', 'х': 'x', 'ц': 'c', 'ч': 'ch', 'ш': 'sh', 'щ': 'sh', 'ъ': '',
  'ы': 'i', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya', 'ў': 'o', 'қ': 'q',
  'ғ': 'g', 'ҳ': 'h',
};

String normalizeMedicineText(String s) {
  final lower = s
      .toLowerCase()
      .replaceAll(RegExp('[\'‘’ʻʼ`´]'), '')
      .replaceAll('-', ' ');
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    b.write(_cyrillic[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _timeout = Duration(seconds: 10);

int _byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

int _newestFirst(Reservation a, Reservation b) =>
    (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));

class SupabasePharmacyRepository implements PharmacyRepository {
  SupabasePharmacyRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  @override
  Future<List<Medicine>> medicines() async {
    final rows = await _client.from('medicines').select().timeout(_timeout);
    return [for (final r in rows) Medicine.fromJson(r)]
      ..sort((a, b) => _byName(a.name, b.name));
  }

  @override
  Future<Medicine?> findByBarcode(String barcode) async {
    final row = await _client
        .from('medicines')
        .select()
        .eq('barcode', barcode.trim())
        .maybeSingle()
        .timeout(_timeout);
    return row == null ? null : Medicine.fromJson(row);
  }

  @override
  Future<List<Pharmacy>> pharmacies() async {
    final rows = await _client.from('pharmacies').select().timeout(_timeout);
    return [for (final r in rows) Pharmacy.fromJson(r)]
      ..sort((a, b) => _byName(a.name, b.name));
  }

  @override
  Future<List<StockItem>> stockFor(String medicineId) async {
    final rows = await _client
        .from('pharmacy_stock')
        .select('*, pharmacies(*)')
        .eq('medicine_id', medicineId)
        .timeout(_timeout);
    return [for (final r in rows) StockItem.fromJson(r)];
  }

  @override
  Future<List<Reservation>> reservations() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('reservations')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .timeout(_timeout);
    return [for (final r in rows) Reservation.fromJson(r)];
  }

  @override
  Stream<List<Reservation>> watchReservations() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return Stream.value(const []);
    return _client
        .from('reservations')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at')
        .map(
          (rows) =>
              [for (final r in rows) Reservation.fromJson(r)]
                ..sort(_newestFirst),
        );
  }

  @override
  Future<Reservation> reserve({
    required String medicineId,
    required String pharmacyId,
    String? forMemberId,
    bool rxAttached = false,
  }) async {
    final row = await _client
        .from('reservations')
        .insert({
          'user_id': _uid,
          'medicine_id': medicineId,
          'pharmacy_id': pharmacyId,
          'for_member_id': forMemberId,
          'rx_attached': rxAttached,
        })
        .select()
        .single()
        .timeout(_timeout);
    return Reservation.fromJson(row);
  }

  @override
  Future<void> cancelReservation(String id) => _client
      .from('reservations')
      .update({'status': ReservationStatus.cancelled.name})
      .eq('id', id)
      .timeout(_timeout);
}

/// Offline: catalog from `assets/pharmacy/*.json`, reservations in
/// SharedPreferences (first use — demo from `fake_pharmacy.json`).
/// The pharmacy is simulated: a `pending` reservation becomes `ready`
/// [readyAfter] after it was made (`null` — never, for tests).
class FakePharmacyRepository implements PharmacyRepository {
  FakePharmacyRepository(
    this._prefs, {
    AssetBundle? bundle,
    this.now,
    this.readyAfter = const Duration(seconds: 20),
  }) : _bundle = bundle ?? rootBundle;

  final SharedPreferences _prefs;
  final AssetBundle _bundle;

  /// Fixed clock for tests; `null` = real clock.
  final DateTime? now;
  final Duration? readyAfter;

  static const medicinesAsset = 'assets/pharmacy/medicines.json';
  static const pharmaciesAsset = 'assets/pharmacy/pharmacies.json';
  static const stockAsset = 'assets/pharmacy/pharmacy_stock.json';
  static const demoAsset = 'assets/pharmacy/fake_pharmacy.json';
  static const reservationsKey = 'pharmacy.fake_reservations';

  DateTime get _now => now ?? DateTime.now();

  List<Medicine>? _medicines;
  List<Pharmacy>? _pharmacies;
  List<StockItem>? _stock;

  final _watchers = <StreamController<List<Reservation>>>{};
  Timer? _readyTimer;

  // Not `loadString`: it caches (a cached future never completes in the next
  // widget test — each test has its own fake async zone) and decodes files
  // over 50 KB (the stock) in an isolate via `compute`, which never finishes
  // under the fake clock of widget tests.
  Future<String> _load(String asset) async {
    final data = await _bundle.load(asset);
    return utf8.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  Future<List<Map<String, dynamic>>> _rows(String asset) async => [
    for (final r in jsonDecode(await _load(asset)) as List)
      r as Map<String, dynamic>,
  ];

  @override
  Future<List<Medicine>> medicines() async => _medicines ??= [
    for (final r in await _rows(medicinesAsset)) Medicine.fromJson(r),
  ]..sort((a, b) => _byName(a.name, b.name));

  @override
  Future<Medicine?> findByBarcode(String barcode) async {
    final code = barcode.trim();
    for (final m in await medicines()) {
      if (m.barcode == code) return m;
    }
    return null;
  }

  @override
  Future<List<Pharmacy>> pharmacies() async => _pharmacies ??= [
    for (final r in await _rows(pharmaciesAsset)) Pharmacy.fromJson(r),
  ]..sort((a, b) => _byName(a.name, b.name));

  @override
  Future<List<StockItem>> stockFor(String medicineId) async {
    _stock ??= [for (final r in await _rows(stockAsset)) StockItem.fromJson(r)];
    final byId = {for (final p in await pharmacies()) p.id: p};
    return [
      for (final s in _stock!)
        if (s.medicineId == medicineId)
          StockItem(
            id: s.id,
            pharmacyId: s.pharmacyId,
            medicineId: s.medicineId,
            priceUzs: s.priceUzs,
            qty: s.qty,
            pharmacy: byId[s.pharmacyId],
          ),
    ];
  }

  Future<List<Reservation>> _all() async {
    final raw = _prefs.getString(reservationsKey);
    if (raw != null) {
      return [
        for (final m in jsonDecode(raw) as List)
          Reservation.fromJson(Map<String, dynamic>.from(m as Map)),
      ];
    }
    final medBySlug = {for (final m in await medicines()) m.slug: m};
    final phBySlug = {for (final p in await pharmacies()) p.slug: p};
    final demo = jsonDecode(await _load(demoAsset)) as Map<String, dynamic>;
    final list = <Reservation>[];
    var i = 0;
    for (final r in demo['reservations'] as List) {
      final m = r as Map<String, dynamic>;
      final med = medBySlug[m['medicine']];
      final ph = phBySlug[m['pharmacy']];
      if (med == null || ph == null) continue;
      list.add(
        Reservation(
          id: 'fake-res-${i++}',
          medicineId: med.id,
          pharmacyId: ph.id,
          forMemberId: m['for_member'] as String?,
          status: ReservationStatus.fromName(m['status'] as String?),
          rxAttached: m['rx_attached'] as bool? ?? false,
          createdAt: _now.subtract(Duration(minutes: m['minutes_ago'] as int)),
        ),
      );
    }
    await _save(list);
    return list;
  }

  Future<void> _save(List<Reservation> list) => _prefs.setString(
    reservationsKey,
    jsonEncode([for (final r in list) r.toJson()]),
  );

  /// `pending → ready` for reservations older than [readyAfter]
  /// (plus [force] ids, whose timer has fired).
  Future<List<Reservation>> _advanced({Set<String> force = const {}}) async {
    final list = await _all();
    final after = readyAfter;
    bool due(Reservation r) =>
        r.status == ReservationStatus.pending &&
        (force.contains(r.id) ||
            (after != null &&
                r.createdAt != null &&
                !_now.isBefore(r.createdAt!.add(after))));
    final changed = list.any(due);
    final out = [
      for (final r in list)
        due(r) ? r.copyWith(status: ReservationStatus.ready) : r,
    ];
    if (changed) await _save(out);
    return out..sort(_newestFirst);
  }

  @override
  Future<List<Reservation>> reservations() => _advanced();

  @override
  Stream<List<Reservation>> watchReservations() {
    late final StreamController<List<Reservation>> c;
    c = StreamController<List<Reservation>>(
      onListen: () {
        _watchers.add(c);
        unawaited(_emit());
      },
      onCancel: () {
        _watchers.remove(c);
        if (_watchers.isEmpty) {
          _readyTimer?.cancel();
          _readyTimer = null;
        }
      },
    );
    return c.stream;
  }

  Future<void> _emit({Set<String> force = const {}}) async {
    final list = await _advanced(force: force);
    for (final c in [..._watchers]) {
      if (!c.isClosed) c.add(list);
    }
    _scheduleReady(list);
  }

  /// One timer for the next pending reservation to become ready.
  void _scheduleReady(List<Reservation> list) {
    _readyTimer?.cancel();
    _readyTimer = null;
    final after = readyAfter;
    if (after == null || _watchers.isEmpty) return;
    Reservation? next;
    for (final r in list) {
      if (r.status != ReservationStatus.pending || r.createdAt == null) {
        continue;
      }
      if (next == null || r.createdAt!.isBefore(next.createdAt!)) next = r;
    }
    if (next == null) return;
    final wait = next.createdAt!.add(after).difference(_now);
    final id = next.id;
    _readyTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _readyTimer = null;
      unawaited(_emit(force: {id}));
    });
  }

  @override
  Future<Reservation> reserve({
    required String medicineId,
    required String pharmacyId,
    String? forMemberId,
    bool rxAttached = false,
  }) async {
    final list = await _all();
    final at = _now;
    final r = Reservation(
      id: 'fake-res-${DateTime.now().microsecondsSinceEpoch}',
      medicineId: medicineId,
      pharmacyId: pharmacyId,
      forMemberId: forMemberId,
      rxAttached: rxAttached,
      createdAt: at,
    );
    await _save([r, ...list]);
    unawaited(_emit());
    return r;
  }

  @override
  Future<void> cancelReservation(String id) async {
    final list = await _all();
    await _save([
      for (final r in list)
        r.id == id ? r.copyWith(status: ReservationStatus.cancelled) : r,
    ]);
    unawaited(_emit());
  }
}

final pharmacyRepositoryProvider = Provider<PharmacyRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakePharmacyRepository(ref.watch(sharedPreferencesProvider))
      : SupabasePharmacyRepository(ref.watch(supabaseClientProvider)),
);
