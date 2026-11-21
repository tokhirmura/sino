import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/pill.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../application/nutrition_math.dart';
import '../../application/nutrition_providers.dart';
import '../labels.dart';

/// Calorie ring to the daily goal, macro bars and bread units.
class CalorieSummaryCard extends ConsumerWidget {
  const CalorieSummaryCard({
    super.key,
    required this.totals,
    required this.goal,
  });

  final NutrientTotals totals;
  final int goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final eaten = totals.kcal.round();
    final left = goal - eaten;
    final over = left < 0;
    final ringColor = over ? AppColors.coral : AppColors.primary;
    final goals = macroGoals(goal);
    final unit = kcalUnit(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TweenAnimationBuilder<double>(
                key: const Key('nutrition-kcal-left'),
                tween: Tween(end: left.abs().toDouble()),
                duration: AppMotion.slow,
                curve: AppMotion.enter,
                builder: (_, v, _) => AnimatedProgressRing(
                  value: goal <= 0 ? 0 : totals.kcal / goal,
                  size: 128,
                  strokeWidth: 12,
                  colors: over
                      ? const [AppColors.saffron, AppColors.coral]
                      : const [AppColors.primary, AppColors.secondary],
                  label: '${v.round()}',
                  caption: over
                      ? context.tr(
                          uz: '$unit ortiqcha',
                          ru: '$unit сверх',
                          en: '$unit over',
                        )
                      : context.tr(
                          uz: '$unit qoldi',
                          ru: '$unit осталось',
                          en: '$unit left',
                        ),
                  semanticsLabel: context.tr(
                    uz: 'Kaloriya: $eaten / $goal',
                    ru: 'Калории: $eaten / $goal',
                    en: 'Calories: $eaten / $goal',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MacroBar(
                      label: context.tr(
                        uz: 'Oqsil',
                        ru: 'Белки',
                        en: 'Protein',
                      ),
                      value: totals.protein,
                      goal: goals.protein,
                      color: AppColors.sky,
                    ),
                    const SizedBox(height: 10),
                    _MacroBar(
                      label: context.tr(uz: 'Yog‘', ru: 'Жиры', en: 'Fat'),
                      value: totals.fat,
                      goal: goals.fat,
                      color: AppColors.amber,
                    ),
                    const SizedBox(height: 10),
                    _MacroBar(
                      label: context.tr(
                        uz: 'Uglevod',
                        ru: 'Углеводы',
                        en: 'Carbs',
                      ),
                      value: totals.carbs,
                      goal: goals.carbs,
                      color: AppColors.violet,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pill(
                context.tr(
                  uz: 'Yeyildi: $eaten $unit',
                  ru: 'Съедено: $eaten $unit',
                  en: 'Eaten: $eaten $unit',
                ),
                color: ringColor,
                icon: Icons.local_fire_department_rounded,
              ),
              Tooltip(
                message: context.tr(
                  uz: '1 non birligi = 12 g uglevod',
                  ru: '1 хлебная единица = 12 г углеводов',
                  en: '1 bread unit = 12 g of carbs',
                ),
                child: Pill(
                  context.tr(
                    uz: 'Non birligi: ${totals.breadUnits.toStringAsFixed(1)}',
                    ru: 'ХЕ: ${totals.breadUnits.toStringAsFixed(1)}',
                    en: 'Bread units: ${totals.breadUnits.toStringAsFixed(1)}',
                  ),
                  color: AppColors.amber,
                  icon: Icons.bakery_dining_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('nutrition-goal-button'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _editGoal(context, ref),
              icon: const Icon(Icons.flag_rounded, size: 18),
              label: Text(
                context.tr(
                  uz: 'Kunlik maqsad: $goal $unit',
                  ru: 'Цель на день: $goal $unit',
                  en: 'Daily goal: $goal $unit',
                ),
                style: text.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editGoal(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_GoalResult>(
      context: context,
      builder: (_) => _GoalDialog(initial: goal),
    );
    if (result == null) return;
    await ref.read(manualKcalGoalProvider.notifier).set(result.goal);
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
  });

  final String label;
  final double value;
  final double goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final g = gramUnit(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${value.round()} / ${goal.round()} $g',
              style: text.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: goal <= 0 ? 0 : (value / goal).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: isDark ? 0.22 : 0.15),
            ),
          ),
        ),
      ],
    );
  }
}

/// `goal == null` — back to the goal from the profile.
class _GoalResult {
  const _GoalResult(this.goal);
  final int? goal;
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.initial});

  final int initial;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final _c = TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final v = int.tryParse(_c.text.trim());
    if (v == null || v < minKcalGoal || v > maxKcalGoal) {
      setState(
        () => _error = context.tr(
          uz: '$minKcalGoal–$maxKcalGoal oralig‘ida kiriting',
          ru: 'Введите от $minKcalGoal до $maxKcalGoal',
          en: 'Enter $minKcalGoal–$maxKcalGoal',
        ),
      );
      return;
    }
    Navigator.of(context).pop(_GoalResult(v));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(
        context.tr(
          uz: 'Kunlik kaloriya maqsadi',
          ru: 'Цель калорий на день',
          en: 'Daily calorie goal',
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('nutrition-goal-field'),
            controller: _c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              suffixText: kcalUnit(context),
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              uz:
                  'Profildan hisoblanadi (Mifflin–San Jeor formulasi, yengil '
                  'faollik). Shifokor maslahatini almashtirmaydi.',
              ru:
                  'Считается по профилю (формула Миффлина–Сан Жеора, лёгкая '
                  'активность). Не заменяет консультацию врача.',
              en:
                  'Calculated from your profile (Mifflin–St Jeor, light '
                  'activity). Does not replace a doctor’s advice.',
            ),
            style: text.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const _GoalResult(null)),
          child: Text(
            context.tr(uz: 'Profildan', ru: 'По профилю', en: 'From profile'),
          ),
        ),
        FilledButton(
          key: const Key('nutrition-goal-save'),
          onPressed: _save,
          child: Text(context.tr(uz: 'Saqlash', ru: 'Сохранить', en: 'Save')),
        ),
      ],
    );
  }
}
