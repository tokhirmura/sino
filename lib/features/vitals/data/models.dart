/// Models of the vitals feature (table `vitals`).
/// Hand-written `fromJson`/`toJson`, no codegen.
library;

enum VitalStatus { low, normal, high }

/// `vitals.kind`. Ranges are general adult reference points for
/// highlighting only — not a diagnosis («Shifokor maslahatini almashtirmaydi»).
enum VitalKind {
  /// beats per minute
  pulse(unit: 'bpm', low: 60, high: 100),

  /// steps per day; below the low mark is «few», no upper limit
  steps(unit: 'steps', low: 5000),

  /// hours of sleep
  sleep(unit: 'h', low: 7, high: 9),

  /// kg; judged through BMI, not here
  weight(unit: 'kg'),

  /// systolic (value) / diastolic (value2), mmHg
  pressure(unit: 'mmHg', low: 90, high: 129, low2: 60, high2: 84),

  /// fasting glucose, mmol/L
  glucose(unit: 'mmol/L', low: 3.9, high: 5.5);

  const VitalKind({
    required this.unit,
    this.low,
    this.high,
    this.low2,
    this.high2,
  });

  final String unit;
  final double? low;
  final double? high;

  /// Range of the second value (diastolic pressure).
  final double? low2;
  final double? high2;

  bool get hasSecondValue => this == VitalKind.pressure;

  /// Unknown kinds from the DB (e.g. `temp`) → `null`, skipped by the UI.
  static VitalKind? fromName(String? s) {
    for (final k in values) {
      if (k.name == s) return k;
    }
    return null;
  }
}

VitalStatus _rangeStatus(double v, double? low, double? high) {
  if (low != null && v < low) return VitalStatus.low;
  if (high != null && v > high) return VitalStatus.high;
  return VitalStatus.normal;
}

/// A row of `vitals`.
class Vital {
  const Vital({
    required this.id,
    required this.kind,
    required this.value,
    required this.measuredAt,
    this.value2,
  });

  final String id;
  final VitalKind kind;
  final double value;

  /// Diastolic pressure; `null` for other kinds.
  final double? value2;
  final DateTime measuredAt;

  /// Worst of both values: any high → high, else any low → low.
  VitalStatus get status {
    final a = _rangeStatus(value, kind.low, kind.high);
    final b = value2 == null
        ? VitalStatus.normal
        : _rangeStatus(value2!, kind.low2, kind.high2);
    if (a == VitalStatus.high || b == VitalStatus.high) return VitalStatus.high;
    if (a == VitalStatus.low || b == VitalStatus.low) return VitalStatus.low;
    return VitalStatus.normal;
  }

  /// `null` when the row has an unknown kind.
  static Vital? tryFromJson(Map<String, dynamic> m) {
    final kind = VitalKind.fromName(m['kind'] as String?);
    if (kind == null) return null;
    return Vital(
      id: m['id'] as String,
      kind: kind,
      value: (m['value'] as num).toDouble(),
      value2: (m['value2'] as num?)?.toDouble(),
      measuredAt: DateTime.parse(m['measured_at'] as String).toLocal(),
    );
  }

  factory Vital.fromJson(Map<String, dynamic> m) =>
      tryFromJson(m) ?? (throw FormatException('Unknown vital ${m['kind']}'));

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'value': value,
    'value2': value2,
    'measured_at': measuredAt.toUtc().toIso8601String(),
  };
}

/// A measurement to be saved (batch insert).
typedef VitalInput = ({
  VitalKind kind,
  double value,
  double? value2,
  DateTime measuredAt,
});
