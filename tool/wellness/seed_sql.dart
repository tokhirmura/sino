import 'dart:convert';

/// Builds the catalog seed SQL for `public.foods` and `public.exercises`
/// from `assets/wellness/foods.json` and `exercises.json` (already in the
/// table shape; the `slug` key is asset-only and is skipped).
///
/// Idempotent: `on conflict (id) do update`, so re-running the migration or
/// regenerating it after editing the JSON keeps the same ids.
String buildSeedSql({
  required List<Map<String, dynamic>> foods,
  required List<Map<String, dynamic>> exercises,
}) {
  final b = StringBuffer()
    ..writeln(
      '-- =====================================================================',
    )
    ..writeln('-- Sino — modul C: foods va exercises kataloglari.')
    ..writeln('-- AVTOMATIK yaratilgan: dart run tool/wellness/gen_seed.dart')
    ..writeln(
      '-- Qo‘lda tahrirlamang — assets/wellness/*.json ni o‘zgartiring.',
    )
    ..writeln(
      '-- =====================================================================',
    )
    ..writeln();

  b
    ..writeln(
      'insert into public.foods '
      '(id, name, emoji, portion, kcal, protein, fat, carbs) values',
    )
    ..writeln(
      [
        for (final f in foods)
          '  (${_lit(f['id'])}, ${_json(f['name'])}, ${_lit(f['emoji'])}, '
              '${_lit(f['portion'])}, ${_num(f['kcal'])}, '
              '${_num(f['protein'])}, ${_num(f['fat'])}, ${_num(f['carbs'])})',
      ].join(',\n'),
    )
    ..writeln('on conflict (id) do update set')
    ..writeln(
      '  name = excluded.name, emoji = excluded.emoji, '
      'portion = excluded.portion, kcal = excluded.kcal,',
    )
    ..writeln(
      '  protein = excluded.protein, fat = excluded.fat, '
      'carbs = excluded.carbs;',
    )
    ..writeln();

  b
    ..writeln(
      'insert into public.exercises '
      '(id, type, muscle, name, hint, reps, seconds, kcal_per_min) values',
    )
    ..writeln(
      [
        for (final e in exercises)
          '  (${_lit(e['id'])}, ${_lit(e['type'])}, ${_lit(e['muscle'])}, '
              '${_json(e['name'])}, ${_json(e['hint'])}, ${_num(e['reps'])}, '
              '${_num(e['seconds'])}, ${_num(e['kcal_per_min'])})',
      ].join(',\n'),
    )
    ..writeln('on conflict (id) do update set')
    ..writeln(
      '  type = excluded.type, muscle = excluded.muscle, '
      'name = excluded.name, hint = excluded.hint,',
    )
    ..writeln(
      '  reps = excluded.reps, seconds = excluded.seconds, '
      'kcal_per_min = excluded.kcal_per_min;',
    );
  return b.toString();
}

/// SQL string literal (`'` doubled) or `null`.
String _lit(Object? v) =>
    v == null ? 'null' : "'${v.toString().replaceAll("'", "''")}'";

String _json(Object? v) => '${_lit(jsonEncode(v ?? const {}))}::jsonb';

String _num(Object? v) => v == null ? 'null' : (v as num).toString();
