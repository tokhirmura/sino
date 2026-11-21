import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';
import '../../../core/storage/prefs.dart';

const _timeout = Duration(seconds: 10);

/// A medicine pack in the user's home cabinet (`home_meds`).
class HomeMed {
  const HomeMed({
    required this.id,
    required this.name,
    this.medicineId,
    this.expiryDate,
    this.quantity = 1,
    this.notes,
    this.createdAt,
  });

  final String id;

  /// `medicines.id` when added from the catalog / by barcode.
  final String? medicineId;

  /// Trade name (from the catalog, or typed by hand).
  final String name;

  /// Date only; `null` — unknown.
  final DateTime? expiryDate;
  final int quantity;
  final String? notes;
  final DateTime? createdAt;

  HomeMed copyWith({
    String? id,
    String? name,
    String? medicineId,
    DateTime? expiryDate,
    int? quantity,
    String? notes,
    DateTime? createdAt,
    bool clearExpiry = false,
    bool clearNotes = false,
    bool clearMedicine = false,
  }) => HomeMed(
    id: id ?? this.id,
    name: name ?? this.name,
    medicineId: clearMedicine ? null : medicineId ?? this.medicineId,
    expiryDate: clearExpiry ? null : expiryDate ?? this.expiryDate,
    quantity: quantity ?? this.quantity,
    notes: clearNotes ? null : notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
  );

  static DateTime? _date(Object? v) {
    if (v == null) return null;
    final d = DateTime.tryParse(v as String);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  factory HomeMed.fromJson(Map<String, dynamic> m) => HomeMed(
    id: m['id'] as String,
    medicineId: m['medicine_id'] as String?,
    name: m['name'] as String,
    expiryDate: _date(m['expiry_date']),
    quantity: (m['quantity'] as num?)?.toInt() ?? 1,
    notes: m['notes'] as String?,
    createdAt: m['created_at'] == null
        ? null
        : DateTime.tryParse(m['created_at'] as String)?.toLocal(),
  );

  /// Columns written by the app (no id / user_id / created_at).
  Map<String, dynamic> toRow() => {
    'medicine_id': medicineId,
    'name': name.trim(),
    'expiry_date': expiryDate == null ? null : _dateStr(expiryDate!),
    'quantity': quantity,
    'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    ...toRow(),
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
}

abstract class HomeMedsRepository {
  /// The user's home medicines (any order).
  Future<List<HomeMed>> list();
  Future<HomeMed> add(HomeMed draft);
  Future<HomeMed> update(HomeMed med);
  Future<void> remove(String id);
}

class SupabaseHomeMedsRepository implements HomeMedsRepository {
  SupabaseHomeMedsRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  @override
  Future<List<HomeMed>> list() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('home_meds')
        .select()
        .eq('user_id', uid)
        .order('expiry_date', ascending: true, nullsFirst: false)
        .timeout(_timeout);
    return [for (final r in rows) HomeMed.fromJson(r)];
  }

  @override
  Future<HomeMed> add(HomeMed draft) async {
    final row = await _client
        .from('home_meds')
        .insert({...draft.toRow(), 'user_id': _uid})
        .select()
        .single()
        .timeout(_timeout);
    return HomeMed.fromJson(row);
  }

  @override
  Future<HomeMed> update(HomeMed med) async {
    final row = await _client
        .from('home_meds')
        .update(med.toRow())
        .eq('id', med.id)
        .select()
        .single()
        .timeout(_timeout);
    return HomeMed.fromJson(row);
  }

  @override
  Future<void> remove(String id) =>
      _client.from('home_meds').delete().eq('id', id).timeout(_timeout);
}

/// Offline: the cabinet in SharedPreferences; on first use — the demo from
/// `assets/pharmacy/fake_pharmacy.json` (`home_meds`, expiry relative to
/// today, `medicine` = catalog slug).
class FakeHomeMedsRepository implements HomeMedsRepository {
  FakeHomeMedsRepository(
    this._prefs, {
    AssetBundle? bundle,
    this.now,
    DateTime Function()? clock,
  }) : _bundle = bundle ?? rootBundle,
       _clock = clock ?? DateTime.now;

  final SharedPreferences _prefs;
  final AssetBundle _bundle;

  /// Fixed "now" for tests; `null` = real clock.
  final DateTime? now;
  final DateTime Function() _clock;

  static const demoAsset = 'assets/pharmacy/fake_pharmacy.json';
  static const medicinesAsset = 'assets/pharmacy/medicines.json';
  static const storeKey = 'pharmacy.fake_home_meds';

  DateTime get _now => now ?? _clock();

  Future<void>? _seeding;

  // `load` + utf8, not `loadString` (see FakePharmacyRepository).
  Future<dynamic> _json(String asset) async {
    final data = await _bundle.load(asset);
    return jsonDecode(
      utf8.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
    );
  }

  /// Writes the demo once (memoized: concurrent first reads share it).
  Future<void> _seed() {
    final pending = _seeding;
    if (pending != null) return pending;
    if (_prefs.containsKey(storeKey)) return Future.value();
    return _seeding = _writeDemo().catchError((Object e, StackTrace st) {
      _seeding = null;
      Error.throwWithStackTrace(e, st);
    });
  }

  Future<void> _writeDemo() async {
    final demo = await _json(demoAsset) as Map<String, dynamic>;
    final medicines = await _json(medicinesAsset) as List;
    final bySlug = {
      for (final m in medicines.cast<Map<String, dynamic>>())
        m['slug'] as String: m,
    };
    final today = DateTime(_now.year, _now.month, _now.day);
    var i = 0;
    final list = <HomeMed>[
      for (final r in (demo['home_meds'] as List? ?? const []))
        () {
          final m = r as Map<String, dynamic>;
          final med = bySlug[m['medicine']];
          final days = m['expires_in_days'] as int?;
          return HomeMed(
            id: 'fake-home-${i++}',
            medicineId: med?['id'] as String?,
            name: med?['name'] as String? ?? m['name'] as String,
            expiryDate: days == null
                ? null
                : DateTime(today.year, today.month, today.day + days),
            quantity: m['quantity'] as int? ?? 1,
            notes: m['notes'] as String?,
            createdAt: today.subtract(const Duration(days: 60)),
          );
        }(),
    ];
    await _save(list);
  }

  Future<List<HomeMed>> _all() async {
    await _seed();
    final raw = _prefs.getString(storeKey);
    if (raw == null) return [];
    return [
      for (final m in jsonDecode(raw) as List)
        HomeMed.fromJson(Map<String, dynamic>.from(m as Map)),
    ];
  }

  Future<void> _save(List<HomeMed> list) => _prefs.setString(
    storeKey,
    jsonEncode([for (final m in list) m.toJson()]),
  );

  @override
  Future<List<HomeMed>> list() => _all();

  @override
  Future<HomeMed> add(HomeMed draft) async {
    final list = await _all();
    final saved = draft.copyWith(
      id: 'fake-home-${DateTime.now().microsecondsSinceEpoch}',
      createdAt: _now,
    );
    await _save([...list, saved]);
    return saved;
  }

  @override
  Future<HomeMed> update(HomeMed med) async {
    final list = await _all();
    final i = list.indexWhere((m) => m.id == med.id);
    if (i < 0) throw StateError('Home medicine not found');
    final saved = med.copyWith(createdAt: list[i].createdAt);
    list[i] = saved;
    await _save(list);
    return saved;
  }

  @override
  Future<void> remove(String id) async {
    final list = await _all();
    await _save([
      for (final m in list)
        if (m.id != id) m,
    ]);
  }
}

/// Clock of «Uy dorixonasi» (expiry badges, demo dates); tests fix it.
final homeMedsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final homeMedsRepositoryProvider = Provider<HomeMedsRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeHomeMedsRepository(
          ref.watch(sharedPreferencesProvider),
          clock: ref.watch(homeMedsClockProvider),
        )
      : SupabaseHomeMedsRepository(ref.watch(supabaseClientProvider)),
);
