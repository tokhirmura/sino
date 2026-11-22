/// Store products: «Rollton», a loaf, a cola — by barcode or from the list
/// of popular products. Lookup: products the user entered before (prefs) →
/// `assets/wellness/products.json` → Open Food Facts (online mode only).
/// Not found → the user types the label (per 100 g) and it is remembered.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/backend/backend.dart';
import '../../../core/storage/prefs.dart';
import 'models.dart';

double? _n(Object? v) => switch (v) {
  num n => n.toDouble(),
  String s => double.tryParse(s.replaceAll(',', '.')),
  _ => null,
};

/// Where a product's data came from.
enum ProductOrigin {
  /// `assets/wellness/products.json`.
  local,

  /// Open Food Facts.
  internet,

  /// Typed by the user from the label.
  user,
}

/// A packaged product. Nutrients are per 100 g (or 100 ml when [liquid]).
class Product {
  const Product({
    required this.name,
    required this.kcal,
    this.barcodes = const [],
    this.slug,
    this.emoji = '🛒',
    this.liquid = false,
    this.package,
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
    this.sugar,
    this.salt,
    this.nutriscore,
    this.ingredients,
    this.origin = ProductOrigin.local,
  });

  final List<String> barcodes;
  final String? slug;

  /// `{uz, ru, en}` — show with `context.trMap`.
  final Map<String, dynamic> name;
  final String emoji;

  /// Measured in ml (drinks).
  final bool liquid;

  /// Grams (ml) in one pack, `null` if unknown.
  final double? package;

  final double kcal;
  final double protein;
  final double fat;
  final double carbs;
  final double? sugar;
  final double? salt;

  /// Nutri-Score `a`…`e` (Open Food Facts).
  final String? nutriscore;

  /// Ingredients as printed on the pack (Open Food Facts).
  final String? ingredients;
  final ProductOrigin origin;

  String? get barcode => barcodes.firstOrNull;

  factory Product.fromJson(Map<String, dynamic> m) => Product(
    slug: m['slug'] as String?,
    barcodes: [for (final b in m['barcodes'] as List? ?? const []) '$b'],
    name: Map<String, dynamic>.from(m['name'] as Map),
    emoji: m['emoji'] as String? ?? '🛒',
    liquid: m['unit'] == 'ml',
    package: _n(m['package']),
    kcal: _n(m['kcal']) ?? 0,
    protein: _n(m['protein']) ?? 0,
    fat: _n(m['fat']) ?? 0,
    carbs: _n(m['carbs']) ?? 0,
    sugar: _n(m['sugar']),
    salt: _n(m['salt']),
    nutriscore: m['nutriscore'] as String?,
    ingredients: m['ingredients'] as String?,
    origin: ProductOrigin.values.firstWhere(
      (o) => o.name == m['origin'],
      orElse: () => ProductOrigin.local,
    ),
  );

  Map<String, dynamic> toJson() => {
    if (slug != null) 'slug': slug,
    'barcodes': barcodes,
    'name': name,
    'emoji': emoji,
    'unit': liquid ? 'ml' : 'g',
    'package': package,
    'kcal': kcal,
    'protein': protein,
    'fat': fat,
    'carbs': carbs,
    'sugar': sugar,
    'salt': salt,
    'nutriscore': nutriscore,
    'ingredients': ingredients,
    'origin': origin.name,
  };

  /// A product page of Open Food Facts (`/api/v2/product/<code>.json`);
  /// `null` when it is missing or has no calories.
  static Product? fromOpenFoodFacts(String code, Map<String, dynamic> json) {
    final p = json['product'];
    if (json['status'] != 1 || p is! Map) return null;
    final nutr = p['nutriments'] is Map ? p['nutriments'] as Map : const {};
    final kcal =
        _n(nutr['energy-kcal_100g']) ??
        switch (_n(nutr['energy_100g'])) {
          final kj? => kj / 4.184,
          null => null,
        };
    if (kcal == null) return null;
    String? s(String k) {
      final v = p[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final base = s('product_name') ?? s('generic_name') ?? code;
    final brand = s('brands')?.split(',').first.trim();
    String named(String? n) {
      final name = n ?? base;
      if (brand == null || name.toLowerCase().contains(brand.toLowerCase())) {
        return name;
      }
      return '$brand $name';
    }

    final unit = (s('product_quantity_unit') ?? s('quantity') ?? '')
        .toLowerCase();
    return Product(
      barcodes: [code],
      name: {
        'uz': named(s('product_name_uz')),
        'ru': named(s('product_name_ru')),
        'en': named(s('product_name_en')),
      },
      liquid: RegExp(r'\b(ml|cl|l|мл|л)\b').hasMatch(unit),
      package: _n(p['product_quantity']),
      kcal: kcal,
      protein: _n(nutr['proteins_100g']) ?? 0,
      fat: _n(nutr['fat_100g']) ?? 0,
      carbs: _n(nutr['carbohydrates_100g']) ?? 0,
      sugar: _n(nutr['sugars_100g']),
      salt: _n(nutr['salt_100g']),
      nutriscore: switch (s('nutriscore_grade')) {
        final g? when 'abcde'.contains(g) && g.length == 1 => g,
        _ => null,
      },
      ingredients:
          s('ingredients_text_ru') ??
          s('ingredients_text_en') ??
          s('ingredients_text'),
      origin: ProductOrigin.internet,
    );
  }

  /// [amount] grams (ml) of it as a diary food: one portion = [amount].
  Food toFood(double amount) {
    final k = amount / 100;
    return Food.custom(
      source: FoodSource.barcode,
      name: name,
      emoji: emoji,
      portion: '${_fmt(amount)} ${liquid ? 'ml' : 'g'}',
      kcal: (kcal * k * 10).roundToDouble() / 10,
      protein: (protein * k * 10).roundToDouble() / 10,
      fat: (fat * k * 10).roundToDouble() / 10,
      carbs: (carbs * k * 10).roundToDouble() / 10,
      barcode: barcode,
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
}

/// «Traffic light» of a label (UK FSA thresholds, per 100 g / 100 ml).
enum ProductFlag { sugar, fat, salt, light }

List<ProductFlag> productFlags(Product p) {
  final drink = p.liquid;
  return [
    if ((p.sugar ?? 0) > (drink ? 11.25 : 22.5)) ProductFlag.sugar,
    if (p.fat > (drink ? 8.75 : 17.5)) ProductFlag.fat,
    if ((p.salt ?? 0) > (drink ? 0.75 : 1.5)) ProductFlag.salt,
    if (p.kcal <= (drink ? 20 : 40)) ProductFlag.light,
  ];
}

/// EAN-8 / UPC / EAN-13 / GTIN-14: digits only.
bool isBarcode(String code) => RegExp(r'^\d{8,14}$').hasMatch(code.trim());

abstract class ProductsRepository {
  /// Popular products (assets) and the ones the user entered.
  Future<List<Product>> popular();

  /// `null` — not found (the user can type the label).
  Future<Product?> byBarcode(String code);

  /// Keeps a typed / downloaded product, so its code is known next time.
  Future<void> remember(Product product);
}

/// Offline: assets + products remembered in SharedPreferences.
class FakeProductsRepository implements ProductsRepository {
  FakeProductsRepository(this._prefs, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final SharedPreferences _prefs;
  final AssetBundle _bundle;

  static const asset = 'assets/wellness/products.json';
  static const savedKey = 'nutrition.products';

  /// Remembered products kept at most.
  static const maxSaved = 50;

  List<Product>? _assets;

  Future<List<Product>> _local() async => _assets ??= [
    for (final m
        in jsonDecode(await _bundle.loadString(asset, cache: false)) as List)
      Product.fromJson(m as Map<String, dynamic>),
  ];

  List<Product> _saved() {
    final raw = _prefs.getString(savedKey);
    if (raw == null) return const [];
    try {
      return [
        for (final m in jsonDecode(raw) as List)
          Product.fromJson(Map<String, dynamic>.from(m as Map)),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<Product>> popular() async => [..._saved(), ...await _local()];

  @override
  Future<Product?> byBarcode(String code) async {
    final c = code.trim();
    for (final p in await popular()) {
      if (p.barcodes.contains(c)) return p;
    }
    return null;
  }

  @override
  Future<void> remember(Product product) async {
    final codes = product.barcodes.toSet();
    final rest = [
      for (final p in _saved())
        if (!p.barcodes.any(codes.contains)) p,
    ];
    final list = [product, ...rest].take(maxSaved);
    await _prefs.setString(
      savedKey,
      jsonEncode([for (final p in list) p.toJson()]),
    );
  }
}

/// Online: the same local lookup, then Open Food Facts (its data is
/// remembered, so a product scanned once works offline too).
class OpenFoodFactsProductsRepository extends FakeProductsRepository {
  OpenFoodFactsProductsRepository(super.prefs, this._http, {super.bundle});

  final http.Client _http;

  static const timeout = Duration(seconds: 8);

  @override
  Future<Product?> byBarcode(String code) async {
    final local = await super.byBarcode(code);
    if (local != null || !isBarcode(code)) return local;
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/${code.trim()}.json',
      {
        'fields': [
          'product_name',
          'product_name_uz',
          'product_name_ru',
          'product_name_en',
          'generic_name',
          'brands',
          'quantity',
          'product_quantity',
          'product_quantity_unit',
          'nutriments',
          'nutriscore_grade',
          'ingredients_text',
          'ingredients_text_ru',
          'ingredients_text_en',
        ].join(','),
      },
    );
    final res = await _http
        .get(uri, headers: {'User-Agent': 'Sino/1.0 (health app)'})
        .timeout(timeout);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw http.ClientException('Open Food Facts ${res.statusCode}', uri);
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes));
    if (json is! Map<String, dynamic>) return null;
    final product = Product.fromOpenFoodFacts(code.trim(), json);
    if (product != null) await remember(product);
    return product;
  }
}

final productsHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ref.watch(useFakeProvider)
      ? FakeProductsRepository(prefs)
      : OpenFoodFactsProductsRepository(
          prefs,
          ref.watch(productsHttpClientProvider),
        );
});
