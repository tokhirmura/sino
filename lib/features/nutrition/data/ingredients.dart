/// «O‘zim pishirdim» (cooked it myself): raw ingredients per 100 g and a
/// parser of free text like «guruch 500 g, sabzi 2 ta, 3 osh qoshiq yog‘».
/// Source — `assets/wellness/ingredients.json`, the same in fake and
/// Supabase mode (no table).
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import 'nutrition_repository.dart' show normalizeFoodText;

const ingredientsAsset = 'assets/wellness/ingredients.json';

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

/// A raw ingredient. Nutrients are per 100 g.
class Ingredient {
  const Ingredient({
    required this.slug,
    required this.name,
    required this.kcal,
    this.emoji = '🥄',
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
    this.pieceGrams,
    this.aliases = const [],
  });

  final String slug;

  /// `{uz, ru, en}` — show with `context.trMap`.
  final Map<String, dynamic> name;
  final String emoji;
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  /// Grams in one piece (an egg, a carrot), `null` if it is not counted.
  final double? pieceGrams;

  /// Normalized words to look for. A word matches a text word it starts
  /// («морков» → «морковь», «моркови»); a trailing `$` asks for the whole
  /// word («non$» is bread, «nonushta» is not).
  final List<List<String>> aliases;

  factory Ingredient.fromJson(Map<String, dynamic> m) => Ingredient(
    slug: m['slug'] as String,
    name: Map<String, dynamic>.from(m['name'] as Map),
    emoji: m['emoji'] as String? ?? '🥄',
    kcal: _d(m['kcal']),
    protein: _d(m['protein']),
    fat: _d(m['fat']),
    carbs: _d(m['carbs']),
    pieceGrams: (m['piece_g'] as num?)?.toDouble(),
    aliases: [
      for (final a in m['aliases'] as List? ?? const [])
        normalizeFoodText('$a').split(' '),
    ],
  );
}

Future<List<Ingredient>> loadIngredients({AssetBundle? bundle}) async {
  // cache: false — see FakeNutritionRepository._load.
  final raw = await (bundle ?? rootBundle).loadString(
    ingredientsAsset,
    cache: false,
  );
  return [
    for (final m in jsonDecode(raw) as List)
      Ingredient.fromJson(m as Map<String, dynamic>),
  ];
}

/// One ingredient of a recipe with its amount in grams.
class RecipeLine {
  const RecipeLine(this.ingredient, this.grams, {this.guessed = false});

  final Ingredient ingredient;
  final double grams;

  /// The amount was not given (or its unit was unclear) — worth checking.
  final bool guessed;

  double get kcal => ingredient.kcal * grams / 100;
  double get protein => ingredient.protein * grams / 100;
  double get fat => ingredient.fat * grams / 100;
  double get carbs => ingredient.carbs * grams / 100;

  RecipeLine withGrams(double g) => RecipeLine(ingredient, g);
}

/// What [parseRecipe] understood: ingredients in text order and the parts
/// it could not match (shown to the user as «not recognized»).
class RecipeParse {
  const RecipeParse(this.lines, this.unknown);

  final List<RecipeLine> lines;
  final List<String> unknown;
}

/// How much one unit weighs, or `null` for «pieces» of the ingredient.
class _Unit {
  const _Unit(this.aliases, this.grams, {this.bare = false});

  final List<String> aliases;
  final double? grams;

  /// May stand without a number: «стакан риса» = 1 cup.
  final bool bare;
}

const _units = [
  _Unit(['kg\$', 'kilo', 'кг\$', 'кило', 'kilogram'], 1000),
  _Unit(['g\$', 'gr\$', 'gramm', 'gram', 'г\$', 'гр\$', 'грамм'], 1),
  _Unit(['ml\$', 'мл\$', 'millilitr', 'миллилитр'], 1),
  _Unit(['l\$', 'litr', 'liter', 'litre', 'л\$', 'литр'], 1000),
  _Unit(['choy qoshiq', 'ч л\$', 'чайн лож', 'tsp', 'teaspoon'], 5, bare: true),
  _Unit(
    [
      'osh qoshiq',
      'qoshiq',
      'ст л\$',
      'столов лож',
      'лож',
      'tbsp',
      'tablespoon',
      'spoon',
    ],
    15,
    bare: true,
  ),
  _Unit(['stakan', 'стакан', 'cup'], 200, bare: true),
  _Unit(['piyola', 'пиал'], 150, bare: true),
  _Unit(['kosa', 'миск', 'bowl'], 350, bare: true),
  _Unit(['chimdim', 'щепот', 'pinch'], 1, bare: true),
  _Unit([
    'ta\$',
    'dona',
    'bosh',
    'шт',
    'штук',
    'головк',
    'pcs',
    'pc\$',
    'piece',
  ], null),
];

final _unitWords = [
  for (final u in _units) [for (final a in u.aliases) a.split(' ')],
];

const _wordNumbers = {
  'yarim': 0.5,
  'пол': 0.5,
  'половина': 0.5,
  'half': 0.5,
  'bir': 1.0,
  'один': 1.0,
  'одна': 1.0,
  'одно': 1.0,
  'one': 1.0,
  'a': 1.0,
  'ikki': 2.0,
  'два': 2.0,
  'две': 2.0,
  'two': 2.0,
  'uch': 3.0,
  'три': 3.0,
  'three': 3.0,
  'tort': 4.0,
  'четыре': 4.0,
  'four': 4.0,
  'besh': 5.0,
  'пять': 5.0,
  'five': 5.0,
};

/// Ingredients without calories need no more than a pinch.
const _zeroDefaultGrams = 5.0;

double? _number(String w) {
  final plain = RegExp(r'^\d+(?:[.,]\d+)?$');
  if (plain.hasMatch(w)) return double.parse(w.replaceAll(',', '.'));
  final frac = RegExp(r'^(\d+)/(\d+)$').firstMatch(w);
  if (frac != null) {
    final b = int.parse(frac[2]!);
    return b == 0 ? null : int.parse(frac[1]!) / b;
  }
  return _wordNumbers[w];
}

/// Does [alias] match [words] at [start]? Returns the words it takes.
int _match(List<String> words, int start, List<String> alias) {
  if (start + alias.length > words.length) return 0;
  for (var k = 0; k < alias.length; k++) {
    final a = alias[k];
    final w = words[start + k];
    final ok = a.endsWith('\$')
        ? w == a.substring(0, a.length - 1)
        : w.startsWith(a);
    if (!ok) return 0;
  }
  return alias.length;
}

/// Splits [text] into parts (lines, commas, «va / и / and», «+») and reads
/// each: a number, a unit and an ingredient in either order — «500 g
/// guruch», «guruch 500g», «2 ta tuxum», «яйца 2 шт», «1,5 kg go‘sht»,
/// «yarim stakan sut». Several ingredients in one part share its numbers
/// in order. No amount → one piece or 100 g, marked [RecipeLine.guessed].
RecipeParse parseRecipe(String text, List<Ingredient> ingredients) {
  final lines = <RecipeLine>[];
  final unknown = <String>[];
  final parts = text.split(
    RegExp(r'\n|;|\+|(?<!\d),|,(?!\d)|\s(?:va|ва|и|and|bilan|с|with)\s'),
  );
  for (final part in parts) {
    final words = _words(part);
    if (words.isEmpty) continue;
    final found = _readPart(words, ingredients);
    if (found.isEmpty) {
      final hasLetters = words.any(
        (w) =>
            _number(w) == null && RegExp(r'\p{L}', unicode: true).hasMatch(w),
      );
      if (hasLetters) unknown.add(part.trim());
    }
    lines.addAll(found);
  }
  return RecipeParse(lines, unknown);
}

List<String> _words(String part) {
  final s = normalizeFoodText(part)
      .replaceAll('½', ' 0.5 ')
      // «300g», «2ta», «1,5kg» → «300 g», «2 ta», «1,5 kg».
      .replaceAllMapped(
        RegExp(r'(\d)(\p{L})', unicode: true),
        (m) => '${m[1]} ${m[2]}',
      )
      .replaceAllMapped(
        RegExp(r'(\p{L})(\d)', unicode: true),
        (m) => '${m[1]} ${m[2]}',
      );
  return [
    for (final w in s.split(RegExp(r'[^\p{L}\p{N}.,/]+', unicode: true)))
      if (w.replaceAll(RegExp(r'^[.,/]+|[.,/]+$'), '') case final t
          when t.isNotEmpty)
        t,
  ];
}

typedef _Amount = ({int pos, double value, _Unit? unit});

List<RecipeLine> _readPart(List<String> words, List<Ingredient> all) {
  final used = List<bool>.filled(words.length, false);
  final amounts = <_Amount>[];

  _Unit? unitAt(int i, void Function(int taken) take) {
    for (var u = 0; u < _units.length; u++) {
      for (final alias in _unitWords[u]) {
        final n = _match(words, i, alias);
        if (n > 0) {
          take(n);
          return _units[u];
        }
      }
    }
    return null;
  }

  for (var i = 0; i < words.length; i++) {
    if (used[i]) continue;
    final w = words[i];
    var value = _number(w);
    _Unit? unit;
    // «полкило», «полстакана».
    if (value == null && w.startsWith('пол') && w.length > 3) {
      final rest = [w.substring(3), ...words.skip(i + 1)];
      for (var u = 0; u < _units.length && unit == null; u++) {
        if (_unitWords[u].any((a) => _match(rest, 0, a) == 1)) {
          unit = _units[u];
        }
      }
      if (unit != null) value = 0.5;
    }
    if (value != null) {
      used[i] = true;
      if (unit == null && i + 1 < words.length) {
        unit = unitAt(i + 1, (n) {
          for (var k = 0; k < n; k++) {
            used[i + 1 + k] = true;
          }
        });
      }
      amounts.add((pos: i, value: value, unit: unit));
      continue;
    }
    // A unit without a number: «стакан риса», «qoshiq yog‘».
    final bare = unitAt(i, (_) {});
    if (bare != null && bare.bare) {
      unitAt(i, (n) {
        for (var k = 0; k < n; k++) {
          used[i + k] = true;
        }
      });
      amounts.add((pos: i, value: 1, unit: bare));
    }
  }

  // Ingredients: the longest alias wins, matches do not overlap.
  final candidates = <({int start, int len, int chars, Ingredient ing})>[];
  for (var i = 0; i < words.length; i++) {
    if (used[i]) continue;
    for (final ing in all) {
      for (final alias in ing.aliases) {
        final n = _match(words, i, alias);
        if (n > 0 && !used.sublist(i, i + n).contains(true)) {
          candidates.add((
            start: i,
            len: n,
            chars: alias.join().length,
            ing: ing,
          ));
        }
      }
    }
  }
  candidates.sort((a, b) => b.chars.compareTo(a.chars));
  final picked = <({int start, int len, int chars, Ingredient ing})>[];
  for (final c in candidates) {
    final free = !picked.any(
      (p) => c.start < p.start + p.len && p.start < c.start + c.len,
    );
    if (free) picked.add(c);
  }
  picked.sort((a, b) => a.start.compareTo(b.start));
  // «kungaboqar yog‘i»: two words of one ingredient side by side are one.
  for (var k = picked.length - 1; k > 0; k--) {
    final a = picked[k - 1], b = picked[k];
    if (a.ing == b.ing && a.start + a.len == b.start) picked.removeAt(k);
  }
  if (picked.isEmpty) return const [];

  // Which amount belongs to which ingredient.
  final numbersFirst =
      amounts.isNotEmpty && amounts.first.pos < picked.first.start;
  final out = <RecipeLine>[];
  for (var k = 0; k < picked.length; k++) {
    final p = picked[k];
    _Amount? amount;
    if (picked.length == 1) {
      amount = amounts.firstOrNull;
    } else if (numbersFirst) {
      final from = k == 0 ? -1 : picked[k - 1].start;
      amount = amounts.where((a) => a.pos > from && a.pos < p.start).lastOrNull;
    } else {
      final to = k == picked.length - 1 ? words.length : picked[k + 1].start;
      amount = amounts.where((a) => a.pos > p.start && a.pos < to).firstOrNull;
    }
    out.add(_line(p.ing, amount));
  }
  return out;
}

RecipeLine _line(Ingredient ing, _Amount? a) {
  final piece = ing.pieceGrams;
  if (a == null) {
    if (piece != null) return RecipeLine(ing, piece, guessed: true);
    return RecipeLine(
      ing,
      ing.kcal == 0 ? _zeroDefaultGrams : 100,
      guessed: true,
    );
  }
  final unit = a.unit;
  if (unit != null) {
    final g = unit.grams;
    if (g != null) return RecipeLine(ing, a.value * g);
    return RecipeLine(ing, a.value * (piece ?? 100), guessed: piece == null);
  }
  // A bare number: big ones are grams, small ones pieces (if countable),
  // else kilograms («go‘sht 1» = 1 kg) — the last case is a guess.
  if (a.value >= 10) return RecipeLine(ing, a.value);
  if (piece != null) return RecipeLine(ing, a.value * piece);
  return RecipeLine(ing, a.value * 1000, guessed: true);
}
