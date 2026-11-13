import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sino/features/vitals/data/models.dart';
import 'package:sino/features/vitals/data/vitals_repository.dart';

Vital _v(VitalKind kind, double value, [double? value2]) => Vital(
  id: 'v',
  kind: kind,
  value: value,
  value2: value2,
  measuredAt: DateTime(2026, 11, 14),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fromJson: pressure with value2, unknown kind skipped', () {
    final v = Vital.fromJson({
      'id': 'a',
      'user_id': 'u',
      'kind': 'pressure',
      'value': 120,
      'value2': 80,
      'measured_at': '2026-11-14T05:00:00+00:00',
    });
    expect(v.kind, VitalKind.pressure);
    expect(v.value2, 80);
    expect(Vital.fromJson(v.toJson()).value2, 80);
    expect(
      Vital.tryFromJson({
        'id': 'b',
        'kind': 'temp',
        'value': 36.6,
        'measured_at': '2026-11-14T05:00:00Z',
      }),
      isNull,
    );
  });

  test('status against general reference ranges', () {
    expect(_v(VitalKind.pulse, 72).status, VitalStatus.normal);
    expect(_v(VitalKind.pulse, 110).status, VitalStatus.high);
    expect(_v(VitalKind.sleep, 5).status, VitalStatus.low);
    expect(_v(VitalKind.steps, 20000).status, VitalStatus.normal);
    expect(_v(VitalKind.weight, 140).status, VitalStatus.normal);
    expect(_v(VitalKind.pressure, 120, 80).status, VitalStatus.normal);
    // diastolic alone out of range is enough
    expect(_v(VitalKind.pressure, 120, 92).status, VitalStatus.high);
    expect(_v(VitalKind.pressure, 85, 55).status, VitalStatus.low);
    expect(_v(VitalKind.glucose, 6.1).status, VitalStatus.high);
  });

  group('FakeVitalsRepository', () {
    late FakeVitalsRepository repo;
    final now = DateTime(2026, 11, 14, 12);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = FakeVitalsRepository(
        await SharedPreferences.getInstance(),
        now: now,
      );
    });

    test('demo has a 7-day history per chart kind, newest first', () async {
      for (final k in [VitalKind.pulse, VitalKind.steps, VitalKind.sleep]) {
        final list = await repo.list(kind: k);
        expect(list, hasLength(7), reason: k.name);
        expect(list.first.measuredAt.isAfter(list.last.measuredAt), isTrue);
      }
      final pressure = await repo.list(kind: VitalKind.pressure);
      expect(pressure.every((v) => v.value2 != null), isTrue);
      expect(
        await repo.list(kind: VitalKind.pulse, since: DateTime(2026, 11, 12)),
        hasLength(3),
      );
    });

    test('add and remove', () async {
      final before = (await repo.list()).length;
      final v = await repo.add(kind: VitalKind.glucose, value: 5.0);
      expect(await repo.list(), hasLength(before + 1));
      await repo.remove(v.id);
      expect(await repo.list(), hasLength(before));
    });
  });
}
