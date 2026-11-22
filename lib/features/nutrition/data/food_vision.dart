/// «Rasmdan aniqlash» (beta): a photo of a plate → up to 3 guesses of the
/// dish with grams and nutrients. Online — Edge Function `food-vision`
/// (LLM with vision, the key only in function secrets); offline or when the
/// function fails — a demo guess from the catalog, clearly marked «demo».
/// The photo is sent once and not stored.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';
import 'models.dart';
import 'nutrition_repository.dart';

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

/// One guess: nutrients for [grams] of the dish.
class FoodGuess {
  const FoodGuess({
    required this.name,
    required this.grams,
    required this.kcal,
    this.emoji = '🍽️',
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
    this.confidence = 0,
  });

  /// `{uz, ru, en}`.
  final Map<String, dynamic> name;
  final String emoji;
  final double grams;
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  /// 0…1.
  final double confidence;

  factory FoodGuess.fromJson(Map<String, dynamic> m) => FoodGuess(
    name: Map<String, dynamic>.from(m['name'] as Map),
    emoji: (m['emoji'] as String?)?.trim().isNotEmpty == true
        ? m['emoji'] as String
        : '🍽️',
    grams: _d(m['grams']).clamp(1, 3000).toDouble(),
    kcal: _d(m['kcal']).clamp(0, 5000).toDouble(),
    protein: _d(m['protein']).clamp(0, 500).toDouble(),
    fat: _d(m['fat']).clamp(0, 500).toDouble(),
    carbs: _d(m['carbs']).clamp(0, 1000).toDouble(),
    confidence: _d(m['confidence']).clamp(0, 1).toDouble(),
  );

  /// [amount] grams of the dish as a diary food (one portion = [amount]).
  Food toFood(double amount) {
    final k = grams <= 0 ? 1.0 : amount / grams;
    double r(double v) => (v * k * 10).roundToDouble() / 10;
    return Food.custom(
      source: FoodSource.photo,
      name: name,
      emoji: emoji,
      portion: '${amount.round()} g',
      kcal: r(kcal),
      protein: r(protein),
      fat: r(fat),
      carbs: r(carbs),
    );
  }
}

class VisionResult {
  const VisionResult(this.guesses, {this.demo = false});

  /// Most likely first; empty — no food on the photo.
  final List<FoodGuess> guesses;

  /// Not a real recognition (offline / AI unavailable).
  final bool demo;
}

abstract class FoodVisionRepository {
  Future<VisionResult> recognize(Uint8List jpeg, {required String lang});
}

/// Demo guesses: 3 catalog dishes picked by the photo bytes (the same photo
/// gives the same answer), confidence 62 / 21 / 9 %.
class DemoFoodVisionRepository implements FoodVisionRepository {
  DemoFoodVisionRepository(this._catalog);

  final Future<List<Food>> Function() _catalog;

  static const confidences = [0.62, 0.21, 0.09];

  @override
  Future<VisionResult> recognize(Uint8List jpeg, {required String lang}) async {
    final foods = [
      for (final f in await _catalog())
        if (f.portionGrams != null) f,
    ];
    if (foods.isEmpty) return const VisionResult([], demo: true);
    var seed = jpeg.length;
    for (var i = 0; i < jpeg.length; i += 97) {
      seed = (seed * 31 + jpeg[i]) & 0x3fffffff;
    }
    final picked = <Food>[];
    for (var k = 0; picked.length < 3 && k < foods.length; k++) {
      final f = foods[(seed + k * 7) % foods.length];
      if (!picked.contains(f)) picked.add(f);
    }
    return VisionResult([
      for (var i = 0; i < picked.length; i++)
        FoodGuess(
          name: picked[i].name,
          emoji: picked[i].emoji ?? '🍽️',
          grams: picked[i].portionGrams!,
          kcal: picked[i].kcal,
          protein: picked[i].protein,
          fat: picked[i].fat,
          carbs: picked[i].carbs,
          confidence: confidences[i],
        ),
    ], demo: true);
  }
}

/// Edge Function `food-vision`; any failure (not deployed, no key, offline)
/// falls back to [fallback].
class SupabaseFoodVisionRepository implements FoodVisionRepository {
  SupabaseFoodVisionRepository(this._client, this.fallback);

  final SupabaseClient _client;
  final FoodVisionRepository fallback;

  static const timeout = Duration(seconds: 25);

  @override
  Future<VisionResult> recognize(Uint8List jpeg, {required String lang}) async {
    try {
      final res = await _client.functions
          .invoke(
            'food-vision',
            body: {'image': base64Encode(jpeg), 'lang': lang},
          )
          .timeout(timeout);
      final data = Map<String, dynamic>.from(res.data as Map);
      return VisionResult([
        for (final g in data['dishes'] as List? ?? const [])
          if (g is Map && g['name'] is Map)
            FoodGuess.fromJson(Map<String, dynamic>.from(g)),
      ]);
    } catch (e) {
      debugPrint('food-vision failed, demo guess: $e');
      return fallback.recognize(jpeg, lang: lang);
    }
  }
}

final foodVisionRepositoryProvider = Provider<FoodVisionRepository>((ref) {
  final demo = DemoFoodVisionRepository(
    () => ref.read(nutritionRepositoryProvider).foods(),
  );
  return ref.watch(useFakeProvider)
      ? demo
      : SupabaseFoodVisionRepository(ref.watch(supabaseClientProvider), demo);
});

enum FoodPhotoSource { camera, gallery }

/// Takes a photo of the plate (≤ 1024 px JPEG); `null` — cancelled.
abstract class FoodPhotoPicker {
  Future<Uint8List?> pick(FoodPhotoSource source);
}

class ImagePickerFoodPhotoPicker implements FoodPhotoPicker {
  final _picker = ImagePicker();

  @override
  Future<Uint8List?> pick(FoodPhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == FoodPhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 75,
    );
    return file?.readAsBytes();
  }
}

final foodPhotoPickerProvider = Provider<FoodPhotoPicker>(
  (ref) => ImagePickerFoodPhotoPicker(),
);
