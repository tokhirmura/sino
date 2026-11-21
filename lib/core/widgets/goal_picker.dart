import 'package:flutter/material.dart';

import '../data/health_goal.dart';
import '../l10n/app_lang.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'emoji_box.dart';
import 'motion.dart';

/// Four goal cards, one can be selected (used by the questionnaire and the
/// profile editor).
///
/// ```dart
/// GoalPicker(value: goal, onChanged: (g) => setState(() => goal = g))
/// ```
class GoalPicker extends StatelessWidget {
  const GoalPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final HealthGoal? value;
  final ValueChanged<HealthGoal> onChanged;
  final bool enabled;

  static Color colorOf(HealthGoal g) => switch (g) {
    HealthGoal.loseWeight => AppColors.coral,
    HealthGoal.energy => AppColors.saffron,
    HealthGoal.pressureSugar => AppColors.garnet,
    HealthGoal.family => AppColors.violet,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, g) in HealthGoal.values.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          CascadeIn(
            index: i,
            child: _GoalTile(
              goal: g,
              selected: g == value,
              onTap: enabled ? () => onChanged(g) : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.selected, this.onTap});

  final HealthGoal goal;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final lang = context.lang;
    final color = GoalPicker.colorOf(goal);
    final accent = AppColors.readable(AppColors.primary, theme.brightness);
    final radius = BorderRadius.circular(AppRadius.input + 4);

    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        enabled: onTap != null,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            key: ValueKey('goal-${goal.code}'),
            duration: AppMotion.fast,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.10)
                  : scheme.surface,
              borderRadius: radius,
              border: Border.all(
                color: selected ? accent : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                EmojiBox(emoji: goal.emoji, color: color, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title(lang),
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(goal.hint(lang), style: text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: AppMotion.fast,
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(selected),
                    color: selected ? accent : scheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
