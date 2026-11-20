// Generates the module B catalog seed migration from assets/pharmacy/*.json.
//
//   dart run tool/pharmacy/gen_seed.dart [output.sql]
//
// Default output: supabase/migrations/20261117120000_pharmacy_seed.sql
// The migration is applied by the lead (`supabase db push`), never here.
import 'dart:convert';
import 'dart:io';

import 'seed_sql.dart';

const defaultOut = 'supabase/migrations/20261117120000_pharmacy_seed.sql';

List<Map<String, dynamic>> _read(String path) => [
  for (final r in jsonDecode(File(path).readAsStringSync()) as List)
    r as Map<String, dynamic>,
];

void main(List<String> args) {
  final out = args.isEmpty ? defaultOut : args.first;
  final medicines = _read('assets/pharmacy/medicines.json');
  final pharmacies = _read('assets/pharmacy/pharmacies.json');
  final stock = _read('assets/pharmacy/pharmacy_stock.json');
  final doctors = _read('assets/pharmacy/doctors.json');
  File(out).writeAsStringSync(
    buildPharmacySeedSql(
      medicines: medicines,
      pharmacies: pharmacies,
      stock: stock,
      doctors: doctors,
    ),
  );
  stdout.writeln(
    'Wrote $out: ${medicines.length} medicines, ${pharmacies.length} '
    'pharmacies, ${stock.length} stock rows, ${doctors.length} doctors',
  );
}
