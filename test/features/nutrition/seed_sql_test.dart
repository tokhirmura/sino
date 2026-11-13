import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/wellness/seed_sql.dart';

List<Map<String, dynamic>> _asset(String name) => [
  for (final r
      in jsonDecode(File('assets/wellness/$name').readAsStringSync()) as List)
    r as Map<String, dynamic>,
];

void main() {
  final foods = _asset('foods.json');
  final exercises = _asset('exercises.json');
  final sql = buildSeedSql(foods: foods, exercises: exercises);

  test('seed contains every catalog id and upserts', () {
    for (final r in [...foods, ...exercises]) {
      expect(sql, contains("'${r['id']}'"));
    }
    expect('on conflict (id) do update'.allMatches(sql), hasLength(2));
    expect(sql, contains('kcal_per_min'));
  });

  test('quotes are escaped and slug is not a column', () {
    expect(sql, contains("Child''s pose"));
    expect(sql, isNot(contains('slug')));
  });

  test('checked-in migration is up to date with the assets', () {
    final file = File('supabase/migrations/20261114120100_wellness_seed.sql');
    expect(
      file.readAsStringSync(),
      sql,
      reason: 'Run: dart run tool/wellness/gen_seed.dart',
    );
  });
}
