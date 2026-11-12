import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/user.dart';

/// Parts of the daily health index. Each has its own max points;
/// all maxes add up to 100.
enum IndexFactor {
  bmi(40),
  age(20),
  medical(20),
  activity(20);

  const IndexFactor(this.max);
  final int max;
}

enum BmiCategory { under, normal, over, obese }

/// What the user can do to raise the index.
enum HealthTip { lowerWeight, gainWeight, addBloodType, startActivity }

class IndexPart {
  const IndexPart(this.factor, this.points);
  final IndexFactor factor;
  final int points;
}

/// «Indeks of the day», v1: computed only from the profile questionnaire.
///
/// - bmi (40): BMI 18.5–24.9 → 40, else −4 per BMI unit outside, min 8
/// - age (20): up to 30 → 20, then −0.4 per year, min 6
/// - medical (20): blood type known → 20
/// - activity (20): no data yet in v1 → neutral 10
///
/// So the best possible v1 score is 90. Not a diagnosis.
class HealthIndex {
  const HealthIndex({
    required this.bmi,
    required this.bmiCategory,
    required this.parts,
    required this.tips,
  });

  final double bmi;
  final BmiCategory bmiCategory;
  final List<IndexPart> parts;
  final List<HealthTip> tips;

  int get score => parts.fold(0, (sum, p) => sum + p.points);

  static const normalBmiLow = 18.5;
  static const normalBmiHigh = 25.0;

  /// `null` until the questionnaire is filled (height, weight, birth year).
  static HealthIndex? fromProfile(UserProfile p, {int? currentYear}) {
    final h = p.heightCm, w = p.weightKg, born = p.birthYear;
    if (h == null || w == null || born == null || h <= 0) return null;
    final age = (currentYear ?? DateTime.now().year) - born;

    final bmi = w / ((h / 100) * (h / 100));
    final category = switch (bmi) {
      < normalBmiLow => BmiCategory.under,
      < normalBmiHigh => BmiCategory.normal,
      < 30 => BmiCategory.over,
      _ => BmiCategory.obese,
    };
    final outside = switch (category) {
      BmiCategory.under => normalBmiLow - bmi,
      BmiCategory.normal => 0.0,
      _ => bmi - normalBmiHigh,
    };
    final bmiPoints = (IndexFactor.bmi.max - outside * 4).round().clamp(
      8,
      IndexFactor.bmi.max,
    );

    final agePoints = (IndexFactor.age.max - (age - 30).clamp(0, 200) * 0.4)
        .round()
        .clamp(6, IndexFactor.age.max);

    final hasBloodType = (p.bloodType ?? '').trim().isNotEmpty;
    final medicalPoints = hasBloodType ? IndexFactor.medical.max : 0;

    const activityPoints = 10;

    return HealthIndex(
      bmi: bmi,
      bmiCategory: category,
      parts: [
        IndexPart(IndexFactor.bmi, bmiPoints),
        IndexPart(IndexFactor.age, agePoints),
        IndexPart(IndexFactor.medical, medicalPoints),
        const IndexPart(IndexFactor.activity, activityPoints),
      ],
      tips: [
        if (category == BmiCategory.under) HealthTip.gainWeight,
        if (category == BmiCategory.over || category == BmiCategory.obese)
          HealthTip.lowerWeight,
        if (!hasBloodType) HealthTip.addBloodType,
        HealthTip.startActivity,
      ],
    );
  }
}

/// Index of the current user; `null` data while the profile is incomplete.
final healthIndexProvider = Provider<AsyncValue<HealthIndex?>>(
  (ref) => ref
      .watch(currentUserProvider)
      .whenData((u) => u == null ? null : HealthIndex.fromProfile(u)),
);
