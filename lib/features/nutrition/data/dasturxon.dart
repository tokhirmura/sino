/// «Dasturxon» (Sprint 2.0, S2-1): the 12 most eaten dishes with home
/// measures (kosa, likopcha, dona, piyola, choy qoshiq) in grams.
///
/// Source — `assets/wellness/dasturxon.json`, the same in fake and Supabase
/// modes: it only points at `foods` rows by their fixed uuids, so no table.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

const dasturxonAsset = 'assets/wellness/dasturxon.json';

/// A household measure. [key] is the value in the JSON.
enum HomeMeasure {
  /// bowl: sho‘rva, lag‘mon, mastava
  kosa('kosa'),

  /// plate: palov, dimlama
  likopcha('likopcha'),

  /// piece: non, somsa, manti, a skewer of shashlik
  dona('dona'),

  /// tea bowl: choy, qatiq
  piyola('piyola'),

  /// teaspoon
  choyQoshiq('choy_qoshiq');

  const HomeMeasure(this.key);

  final String key;

  static HomeMeasure fromKey(String? s) => values.firstWhere(
    (m) => m.key == s,
    orElse: () => throw FormatException('Unknown measure $s'),
  );
}

/// One measure of a dish: «1 kosa = 400 g».
class DasturxonMeasure {
  const DasturxonMeasure(this.measure, this.grams);

  final HomeMeasure measure;
  final double grams;

  factory DasturxonMeasure.fromJson(Map<String, dynamic> m) {
    final grams = (m['grams'] as num).toDouble();
    if (grams <= 0) throw FormatException('Bad grams $grams');
    return DasturxonMeasure(HomeMeasure.fromKey(m['unit'] as String?), grams);
  }
}

/// A dish of the quick-add grid; the first measure is the default one.
class DasturxonItem {
  const DasturxonItem({
    required this.slug,
    required this.foodId,
    required this.measures,
  });

  final String slug;

  /// `foods.id`.
  final String foodId;
  final List<DasturxonMeasure> measures;

  factory DasturxonItem.fromJson(Map<String, dynamic> m) {
    final measures = [
      for (final x in m['measures'] as List)
        DasturxonMeasure.fromJson(x as Map<String, dynamic>),
    ];
    if (measures.isEmpty) throw FormatException('No measures: ${m['slug']}');
    return DasturxonItem(
      slug: m['slug'] as String,
      foodId: m['food_id'] as String,
      measures: measures,
    );
  }
}

List<DasturxonItem> parseDasturxon(String json) => [
  for (final x in (jsonDecode(json) as Map<String, dynamic>)['items'] as List)
    DasturxonItem.fromJson(x as Map<String, dynamic>),
];

Future<List<DasturxonItem>> loadDasturxon([AssetBundle? bundle]) async =>
    parseDasturxon(await (bundle ?? rootBundle).loadString(dasturxonAsset));

/// Portions of [food] in [count] × [m] (e.g. 2 dona somsa), to 0.01;
/// `null` when the food's portion has no grams.
double? dasturxonServings(Food food, DasturxonMeasure m, {double count = 1}) {
  final g = food.portionGrams;
  if (g == null || g <= 0) return null;
  return (m.grams * count / g * 100).round() / 100;
}

/// A dish joined with its catalog row.
typedef DasturxonDish = ({DasturxonItem item, Food food});
