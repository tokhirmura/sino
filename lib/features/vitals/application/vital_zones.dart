/// Blood pressure and glucose zones (Sprint 2.0, S2-1).
///
/// General reference information for colouring and hints — not a diagnosis
/// («Shifokor maslahatini almashtirmaydi»). Boundaries agree with the
/// «normal» ranges of [VitalKind] (pressure 90–129 / 60–84, glucose
/// 3.9–5.5), so «me’yor» here is «me’yorda» on the tiles.
library;

import '../data/models.dart';

/// past / me’yor / yuqori me’yor / baland, from best to most worrying is
/// normal < low < elevated < high (see [worse]).
enum VitalZone {
  low,
  normal,

  /// «yuqori me’yor»: high-normal pressure, raised fasting glucose
  elevated,
  high,
}

/// How worrying a zone is: pressure 135/55 is «elevated», not «low».
int _rank(VitalZone z) => switch (z) {
  VitalZone.normal => 0,
  VitalZone.low => 1,
  VitalZone.elevated => 2,
  VitalZone.high => 3,
};

/// The more worrying of two zones.
VitalZone worse(VitalZone a, VitalZone b) => _rank(b) > _rank(a) ? b : a;

/// A zone over a value range: `from ≤ v < to`; `null` ends are open.
class ZoneBand {
  const ZoneBand(this.zone, {this.from, this.to});

  final VitalZone zone;
  final double? from;
  final double? to;

  bool contains(double v) =>
      (from == null || v >= from!) && (to == null || v < to!);
}

List<ZoneBand> _bands(double low, double elevated, double high) => [
  ZoneBand(VitalZone.low, to: low),
  ZoneBand(VitalZone.normal, from: low, to: elevated),
  ZoneBand(VitalZone.elevated, from: elevated, to: high),
  ZoneBand(VitalZone.high, from: high),
];

/// Systolic, mmHg (ESH): < 90 · 90–129 · 130–139 · ≥ 140.
final systolicBands = _bands(90, 130, 140);

/// Diastolic, mmHg (ESH): < 60 · 60–84 · 85–89 · ≥ 90.
final diastolicBands = _bands(60, 85, 90);

/// Fasting glucose, mmol/L: < 3.9 · 3.9–5.5 · 5.6–6.9 · ≥ 7.0.
final glucoseBands = _bands(3.9, 5.6, 7.0);

VitalZone _zoneIn(List<ZoneBand> bands, double v) =>
    bands.firstWhere((b) => b.contains(v)).zone;

/// Zone of a pressure reading: the more worrying of both values.
VitalZone pressureZone(double systolic, double diastolic) =>
    worse(_zoneIn(systolicBands, systolic), _zoneIn(diastolicBands, diastolic));

VitalZone glucoseZone(double mmolL) => _zoneIn(glucoseBands, mmolL);

/// Zone of a measurement; `null` for kinds without zones and for a pressure
/// row without the lower value.
VitalZone? zoneOf(Vital v) => switch (v.kind) {
  VitalKind.pressure when v.value2 != null => pressureZone(v.value, v.value2!),
  VitalKind.glucose => glucoseZone(v.value),
  _ => null,
};

/// Bands to colour a chart of [kind]: the systolic ones for pressure (its
/// upper line), `[]` for kinds without zones.
List<ZoneBand> chartBands(VitalKind kind) => switch (kind) {
  VitalKind.pressure => systolicBands,
  VitalKind.glucose => glucoseBands,
  _ => const [],
};
