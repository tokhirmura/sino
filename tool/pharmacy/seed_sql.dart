import 'dart:convert';

/// Builds the catalog seed SQL for module B: `public.medicines`,
/// `public.pharmacies`, `public.pharmacy_stock` and `public.doctors` from
/// `assets/pharmacy/*.json` (already in the table shape; the `slug` key is
/// asset-only and is skipped).
///
/// Idempotent: `on conflict (id) do update`, so re-running the migration or
/// regenerating it after editing the JSON keeps the same ids.
String buildPharmacySeedSql({
  required List<Map<String, dynamic>> medicines,
  required List<Map<String, dynamic>> pharmacies,
  required List<Map<String, dynamic>> stock,
  required List<Map<String, dynamic>> doctors,
}) {
  final b = StringBuffer()
    ..writeln(
      '-- =====================================================================',
    )
    ..writeln(
      '-- Sino — modul B: medicines, pharmacies, pharmacy_stock va doctors.',
    )
    ..writeln('-- AVTOMATIK yaratilgan: dart run tool/pharmacy/gen_seed.dart')
    ..writeln(
      '-- Qo‘lda tahrirlamang — assets/pharmacy/*.json ni o‘zgartiring.',
    )
    ..writeln(
      '-- =====================================================================',
    )
    ..writeln();

  b
    ..writeln(
      'insert into public.medicines '
      '(id, name, ingredient, form, category, rx, price_uzs, barcode, '
      'description, warning, analogs) values',
    )
    ..writeln(
      [
        for (final m in medicines)
          '  (${_lit(m['id'])}, ${_lit(m['name'])}, ${_lit(m['ingredient'])}, '
              '${_lit(m['form'])}, ${_lit(m['category'])}, ${_bool(m['rx'])}, '
              '${_num(m['price_uzs'])}, ${_lit(m['barcode'])}, '
              '${_json(m['description'])}, ${_json(m['warning'])}, '
              '${_textArray(m['analogs'])})',
      ].join(',\n'),
    )
    ..writeln('on conflict (id) do update set')
    ..writeln(
      '  name = excluded.name, ingredient = excluded.ingredient, '
      'form = excluded.form, category = excluded.category,',
    )
    ..writeln(
      '  rx = excluded.rx, price_uzs = excluded.price_uzs, '
      'barcode = excluded.barcode, description = excluded.description,',
    )
    ..writeln('  warning = excluded.warning, analogs = excluded.analogs;')
    ..writeln();

  b
    ..writeln(
      'insert into public.pharmacies '
      '(id, name, address, lat, lng, hours, open24, rating) values',
    )
    ..writeln(
      [
        for (final p in pharmacies)
          '  (${_lit(p['id'])}, ${_lit(p['name'])}, ${_lit(p['address'])}, '
              '${_num(p['lat'])}, ${_num(p['lng'])}, ${_lit(p['hours'])}, '
              '${_bool(p['open24'])}, ${_num(p['rating'])})',
      ].join(',\n'),
    )
    ..writeln('on conflict (id) do update set')
    ..writeln(
      '  name = excluded.name, address = excluded.address, '
      'lat = excluded.lat, lng = excluded.lng,',
    )
    ..writeln(
      '  hours = excluded.hours, open24 = excluded.open24, '
      'rating = excluded.rating;',
    )
    ..writeln();

  b
    ..writeln(
      'insert into public.pharmacy_stock '
      '(id, pharmacy_id, medicine_id, price_uzs, qty) values',
    )
    ..writeln(
      [
        for (final s in stock)
          '  (${_lit(s['id'])}, ${_lit(s['pharmacy_id'])}, '
              '${_lit(s['medicine_id'])}, ${_num(s['price_uzs'])}, '
              '${_num(s['qty'])})',
      ].join(',\n'),
    )
    ..writeln('on conflict (id) do update set')
    ..writeln(
      '  pharmacy_id = excluded.pharmacy_id, '
      'medicine_id = excluded.medicine_id,',
    )
    ..writeln('  price_uzs = excluded.price_uzs, qty = excluded.qty;')
    ..writeln();

  b
    ..writeln(
      'insert into public.doctors '
      '(id, name, specialty, years, rating, price_uzs, clinic, online) values',
    )
    ..writeln(
      [
        for (final d in doctors)
          '  (${_lit(d['id'])}, ${_lit(d['name'])}, ${_lit(d['specialty'])}, '
              '${_num(d['years'])}, ${_num(d['rating'])}, '
              '${_num(d['price_uzs'])}, ${_lit(d['clinic'])}, '
              '${_bool(d['online'])})',
      ].join(',\n'),
    )
    ..writeln('on conflict (id) do update set')
    ..writeln(
      '  name = excluded.name, specialty = excluded.specialty, '
      'years = excluded.years, rating = excluded.rating,',
    )
    ..writeln(
      '  price_uzs = excluded.price_uzs, clinic = excluded.clinic, '
      'online = excluded.online;',
    );
  return b.toString();
}

/// SQL string literal (`'` doubled) or `null`.
String _lit(Object? v) =>
    v == null ? 'null' : "'${v.toString().replaceAll("'", "''")}'";

String _json(Object? v) => '${_lit(jsonEncode(v ?? const {}))}::jsonb';

String _num(Object? v) => v == null ? 'null' : (v as num).toString();

String _bool(Object? v) => v == true ? 'true' : 'false';

String _textArray(Object? v) {
  final items = [for (final e in (v as List?) ?? const []) _lit(e)];
  return items.isEmpty ? "'{}'::text[]" : 'array[${items.join(', ')}]::text[]';
}
