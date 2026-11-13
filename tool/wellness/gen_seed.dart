// Generates the catalog seed migration from assets/wellness/*.json.
//
//   dart run tool/wellness/gen_seed.dart [output.sql]
//
// Default output: supabase/migrations/20261114120100_wellness_seed.sql
// The migration is applied by the lead (`supabase db push`), never here.
import 'dart:convert';
import 'dart:io';

import 'seed_sql.dart';

const defaultOut = 'supabase/migrations/20261114120100_wellness_seed.sql';

List<Map<String, dynamic>> _read(String path) => [
  for (final r in jsonDecode(File(path).readAsStringSync()) as List)
    r as Map<String, dynamic>,
];

void main(List<String> args) {
  final out = args.isEmpty ? defaultOut : args.first;
  final foods = _read('assets/wellness/foods.json');
  final exercises = _read('assets/wellness/exercises.json');
  File(out).writeAsStringSync(buildSeedSql(foods: foods, exercises: exercises));
  stdout.writeln(
    'Wrote $out: ${foods.length} foods, ${exercises.length} exercises',
  );
}
