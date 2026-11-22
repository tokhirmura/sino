import 'package:flutter/material.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../labels.dart';

/// Pieces shared by the photo, homemade and barcode screens.

void showNutritionSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// A selectable row: emoji, title, subtitle, a value on the right; the
/// selected one gets a colored border.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.emoji,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String emoji;
  final Color color;
  final String title;
  final String subtitle;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return Material(
      color: selected
          ? color.withValues(alpha: 0.12)
          : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        side: BorderSide(
          color: selected ? color : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              EmojiBox(emoji: emoji, color: color, size: 40),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(subtitle, style: text.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  trailing!,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
              const SizedBox(width: AppSpacing.xxs),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? color : theme.colorScheme.outline,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «520 kkal · O 18 g · Y 30 g · U 64 g» of one portion of [food].
class NutrientLine extends StatelessWidget {
  const NutrientLine({super.key, required this.food, this.style});

  final Food food;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    nutrientText(
      context,
      kcal: food.kcal,
      protein: food.protein,
      fat: food.fat,
      carbs: food.carbs,
    ),
    style: style ?? Theme.of(context).textTheme.bodyMedium,
  );
}

String nutrientText(
  BuildContext context, {
  required double kcal,
  required double protein,
  required double fat,
  required double carbs,
}) {
  final g = gramUnit(context);
  final k = '${kcal.round()} ${kcalUnit(context)}';
  final p = protein.round(), f = fat.round(), c = carbs.round();
  return context.tr(
    uz: '$k · O $p$g · Y $f$g · U $c$g',
    ru: '$k · Б $p$g · Ж $f$g · У $c$g',
    en: '$k · P $p$g · F $f$g · C $c$g',
  );
}
