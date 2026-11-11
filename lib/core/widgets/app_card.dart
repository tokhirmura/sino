import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'emoji_box.dart';

/// Rounded (20) card with a soft shadow and optional tap.
///
/// The shadow is skipped automatically for translucent [color]s
/// (it would show through) and when [elevated] is false.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.elevated = true,
    this.gradient,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry padding;

  /// Draw the soft shadow (light theme) / hairline border (dark theme).
  final bool elevated;

  /// Optional background gradient; overrides [color].
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppColors.cardRadius);
    final bg = color ?? theme.cardTheme.color ?? theme.colorScheme.surface;
    final opaque = gradient == null && bg.a >= 1;
    final showShadow = elevated && (opaque || gradient != null);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: gradient,
        boxShadow: showShadow ? AppShadows.soft(theme.brightness) : null,
      ),
      child: Material(
        color: gradient == null ? bg : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: isDark && elevated && gradient == null
              ? BorderSide(color: theme.colorScheme.outlineVariant)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Standard shortcut card for home: emoji + title + subtitle + chevron.
class ShortcutCard extends StatelessWidget {
  const ShortcutCard({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.color = AppColors.primary,
    this.onTap,
    this.trailing,
  });

  final String emoji;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;

  /// Replaces the default chevron (shown only when [onTap] is set).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final trail =
        trailing ??
        (onTap == null
            ? null
            : Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ));
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          EmojiBox(emoji: emoji, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trail != null) ...[const SizedBox(width: 8), trail],
        ],
      ),
    );
  }
}
