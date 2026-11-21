import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_card.dart';

/// Big number + label + icon, e.g. «8 432 · qadam», «72 · zarba/daq».
///
/// ```dart
/// Row(children: [
///   Expanded(child: StatTile(value: '1 520', unit: 'kkal',
///       label: 'Bugun', icon: Icons.local_fire_department_rounded,
///       color: AppColors.saffron)),
///   const SizedBox(width: 12),
///   Expanded(child: StatTile(value: '6/8', label: 'Suv', emoji: '💧',
///       color: AppColors.sky)),
/// ])
/// ```
///
/// [onDark] — white text for use on a [GradientHeader].
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.icon,
    this.emoji,
    this.color = AppColors.primary,
    this.caption,
    this.onTap,
    this.onDark = false,
  });

  final String value;
  final String label;
  final String? unit;
  final IconData? icon;
  final String? emoji;
  final Color color;

  /// Small hint under the label (trend, goal).
  final String? caption;
  final VoidCallback? onTap;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final brightness = theme.brightness;
    final ink = onDark ? Colors.white : theme.colorScheme.onSurface;
    final soft = onDark
        ? Colors.white.withValues(alpha: 0.8)
        : theme.colorScheme.onSurfaceVariant;
    final accent = onDark
        ? Colors.white
        : AppColors.readable(color, brightness);

    final badge = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.18)
            : color.withValues(
                alpha: brightness == Brightness.dark ? 0.22 : 0.13,
              ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: emoji != null
          ? Text(
              emoji!,
              style: const TextStyle(fontSize: 18, height: 1.1),
              textScaler: TextScaler.noScaling,
            )
          : Icon(icon ?? Icons.insights_rounded, size: 20, color: accent),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: text.headlineMedium?.copyWith(color: ink, height: 1),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit!, style: text.titleSmall?.copyWith(color: soft)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: text.bodyMedium?.copyWith(
            color: soft,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            style: text.bodySmall?.copyWith(color: accent),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    if (onDark) {
      return Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.cardRadius - 4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(14), child: body),
        ),
      );
    }
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: body,
    );
  }
}
