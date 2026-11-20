import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/pharmacy/seed_sql.dart';

List<Map<String, dynamic>> _asset(String name) => [
  for (final r
      in jsonDecode(File('assets/pharmacy/$name').readAsStringSync()) as List)
    r as Map<String, dynamic>,
];

void main() {
  final medicines = _asset('medicines.json');
  final pharmacies = _asset('pharmacies.json');
  final stock = _asset('pharmacy_stock.json');
  final doctors = _asset('doctors.json');
  final sql = buildPharmacySeedSql(
    medicines: medicines,
    pharmacies: pharmacies,
    stock: stock,
    doctors: doctors,
  );

  test('seed contains every catalog id and upserts all 4 tables', () {
    for (final r in [...medicines, ...pharmacies, ...stock, ...doctors]) {
      expect(sql, contains("'${r['id']}'"));
    }
    expect('on conflict (id) do update'.allMatches(sql), hasLength(4));
    // Parents before children (pharmacy_stock references both).
    expect(
      sql.indexOf('insert into public.pharmacy_stock'),
      greaterThan(sql.indexOf('insert into public.pharmacies')),
    );
  });

  test('analogs as text[], quotes escaped, slug is not a column', () {
    expect(sql, contains('::text[]'));
    expect(sql, contains("'{}'::text[]"));
    expect(sql, isNot(contains('slug')));
    final quoted = buildPharmacySeedSql(
      medicines: const [],
      pharmacies: const [],
      stock: const [],
      doctors: [
        {...doctors.first, 'name': "Dr O'Brien"},
      ],
    );
    expect(quoted, contains("'Dr O''Brien'"));
  });

  test('checked-in migration is up to date with the assets', () {
    final file = File('supabase/migrations/20261117120000_pharmacy_seed.sql');
    expect(
      file.readAsStringSync(),
      sql,
      reason: 'Run: dart run tool/pharmacy/gen_seed.dart',
    );
  });
}
