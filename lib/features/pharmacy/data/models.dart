/// Models of the pharmacy feature (tables `medicines`, `pharmacies`,
/// `pharmacy_stock`, `reservations`). Hand-written `fromJson`/`toJson`,
/// no codegen.
library;

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

DateTime? _time(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

Map<String, dynamic> _texts(Object? v) =>
    Map<String, dynamic>.from(v as Map? ?? const {});

/// Dose forms used in `medicines.form` (labels live in the UI).
const medicineForms = [
  'tablet',
  'capsule',
  'syrup',
  'powder',
  'spray',
  'drops',
  'ointment',
];

/// Categories used in `medicines.category` (labels live in the UI).
const medicineCategories = [
  'pain',
  'cold',
  'allergy',
  'stomach',
  'heart',
  'diabetes',
  'antibiotic',
  'vitamins',
  'skin',
  'eye',
  'nerves',
];

/// A row of the `medicines` catalog.
class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    this.slug,
    this.ingredient,
    this.form,
    this.category,
    this.rx = false,
    this.priceUzs,
    this.barcode,
    this.description = const {},
    this.warning = const {},
    this.analogs = const [],
  });

  final String id;

  /// Asset-only readable id (`ibuprofen`); `null` for rows from Supabase.
  final String? slug;

  /// Trade name with strength, e.g. `Nurofen 200 mg` (not translated).
  final String name;

  /// Active ingredient(s) in English, lower case, `+` between them.
  final String? ingredient;

  /// One of [medicineForms].
  final String? form;

  /// One of [medicineCategories].
  final String? category;

  /// Prescription-only: a reservation needs a prescription attached.
  final bool rx;

  /// Reference price; real prices are per pharmacy in `pharmacy_stock`.
  final int? priceUzs;

  /// EAN-13.
  final String? barcode;

  /// `{uz, ru, en}` — show with `context.trMap`.
  final Map<String, dynamic> description;
  final Map<String, dynamic> warning;

  /// Ids of catalog medicines with the SAME active ingredient (generic
  /// substitutes). Never a different substance — that needs a doctor.
  final List<String> analogs;

  factory Medicine.fromJson(Map<String, dynamic> m) => Medicine(
    id: m['id'] as String,
    slug: m['slug'] as String?,
    name: m['name'] as String,
    ingredient: m['ingredient'] as String?,
    form: m['form'] as String?,
    category: m['category'] as String?,
    rx: m['rx'] as bool? ?? false,
    priceUzs: (m['price_uzs'] as num?)?.toInt(),
    barcode: m['barcode'] as String?,
    description: _texts(m['description']),
    warning: _texts(m['warning']),
    analogs: List<String>.from(m['analogs'] as List? ?? const []),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (slug != null) 'slug': slug,
    'name': name,
    'ingredient': ingredient,
    'form': form,
    'category': category,
    'rx': rx,
    'price_uzs': priceUzs,
    'barcode': barcode,
    'description': description,
    'warning': warning,
    'analogs': analogs,
  };
}

/// A row of the `pharmacies` catalog.
class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.slug,
    this.address,
    this.hours,
    this.open24 = false,
    this.rating,
  });

  final String id;
  final String? slug;
  final String name;
  final String? address;
  final double lat;
  final double lng;

  /// Free text, e.g. `08:00–22:00`; `24/7` when [open24].
  final String? hours;
  final bool open24;
  final double? rating;

  factory Pharmacy.fromJson(Map<String, dynamic> m) => Pharmacy(
    id: m['id'] as String,
    slug: m['slug'] as String?,
    name: m['name'] as String,
    address: m['address'] as String?,
    lat: _d(m['lat']),
    lng: _d(m['lng']),
    hours: m['hours'] as String?,
    open24: m['open24'] as bool? ?? false,
    rating: (m['rating'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (slug != null) 'slug': slug,
    'name': name,
    'address': address,
    'lat': lat,
    'lng': lng,
    'hours': hours,
    'open24': open24,
    'rating': rating,
  };
}

/// A row of `pharmacy_stock`, optionally with the joined [pharmacy]
/// (`select('*, pharmacies(*)')`).
class StockItem {
  const StockItem({
    required this.id,
    required this.pharmacyId,
    required this.medicineId,
    required this.priceUzs,
    required this.qty,
    this.pharmacy,
  });

  final String id;
  final String pharmacyId;
  final String medicineId;
  final int priceUzs;
  final int qty;
  final Pharmacy? pharmacy;

  bool get inStock => qty > 0;

  factory StockItem.fromJson(Map<String, dynamic> m) => StockItem(
    id: m['id'] as String,
    pharmacyId: m['pharmacy_id'] as String,
    medicineId: m['medicine_id'] as String,
    priceUzs: (m['price_uzs'] as num).toInt(),
    qty: (m['qty'] as num?)?.toInt() ?? 0,
    pharmacy: m['pharmacies'] is Map
        ? Pharmacy.fromJson(Map<String, dynamic>.from(m['pharmacies'] as Map))
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'pharmacy_id': pharmacyId,
    'medicine_id': medicineId,
    'price_uzs': priceUzs,
    'qty': qty,
  };
}

enum ReservationStatus {
  pending,
  ready,
  picked,
  cancelled;

  static ReservationStatus fromName(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => pending);

  /// Still waiting to be picked up — can be cancelled.
  bool get isActive => this == pending || this == ready;
}

/// A row of `reservations`. [medicine] / [pharmacy] are filled from the
/// catalog (realtime rows have no joins) — see [resolve].
class Reservation {
  const Reservation({
    required this.id,
    required this.medicineId,
    required this.pharmacyId,
    this.forMemberId,
    this.status = ReservationStatus.pending,
    this.rxAttached = false,
    this.createdAt,
    this.medicine,
    this.pharmacy,
  });

  final String id;
  final String medicineId;
  final String pharmacyId;

  /// `family_members.id`; `null` = for the user.
  final String? forMemberId;
  final ReservationStatus status;

  /// A prescription photo was attached (the photo itself stays on the
  /// device — the table has only this flag).
  final bool rxAttached;
  final DateTime? createdAt;
  final Medicine? medicine;
  final Pharmacy? pharmacy;

  factory Reservation.fromJson(Map<String, dynamic> m) => Reservation(
    id: m['id'] as String,
    medicineId: m['medicine_id'] as String,
    pharmacyId: m['pharmacy_id'] as String,
    forMemberId: m['for_member_id'] as String?,
    status: ReservationStatus.fromName(m['status'] as String?),
    rxAttached: m['rx_attached'] as bool? ?? false,
    createdAt: _time(m['created_at']),
  );

  /// For the fake store (no joins, ids only).
  Map<String, dynamic> toJson() => {
    'id': id,
    'medicine_id': medicineId,
    'pharmacy_id': pharmacyId,
    'for_member_id': forMemberId,
    'status': status.name,
    'rx_attached': rxAttached,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };

  /// Fills [medicine] / [pharmacy] from the catalog maps (by id).
  Reservation resolve(
    Map<String, Medicine> medicines,
    Map<String, Pharmacy> pharmacies,
  ) => Reservation(
    id: id,
    medicineId: medicineId,
    pharmacyId: pharmacyId,
    forMemberId: forMemberId,
    status: status,
    rxAttached: rxAttached,
    createdAt: createdAt,
    medicine: medicine ?? medicines[medicineId],
    pharmacy: pharmacy ?? pharmacies[pharmacyId],
  );

  Reservation copyWith({ReservationStatus? status}) => Reservation(
    id: id,
    medicineId: medicineId,
    pharmacyId: pharmacyId,
    forMemberId: forMemberId,
    status: status ?? this.status,
    rxAttached: rxAttached,
    createdAt: createdAt,
    medicine: medicine,
    pharmacy: pharmacy,
  );
}
