import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';

/// Achievement medal: emoji on a saffron gradient with a white rim, title
/// under it. Locked — grey, faded emoji and a small lock.
///
/// ```dart
/// AchievementBadge(emoji: '🔥', title: '7 kun ketma-ket', unlocked: true)
/// ```
///
/// Unlocked badges "pop" in with a spring when they appear.
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.unlocked = true,
    this.color = AppColors.saffron,
    this.size = 72,
    this.onTap,
  });

  final String emoji;
  final String title;
  final String? subtitle;
  final bool unlocked;

  /// Medal color; saffron by default (rewards).
  final Color color;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final grey = isDark ? const Color(0xFF2A3550) : const Color(0xFFE6E1D8);

    Widget medal = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: unlocked
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(color, Colors.white, 0.35)!,
                  color,
                  Color.lerp(color, Colors.black, 0.15)!,
                ],
              )
            : null,
        color: unlocked ? null : grey,
        border: Border.all(
          color: unlocked ? Colors.white : grey,
          width: size * 0.05,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: size * 0.3,
                  spreadRadius: -size * 0.06,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      child: Opacity(
        opacity: unlocked ? 1 : 0.35,
        child: Text(
          emoji,
          style: TextStyle(fontSize: size * 0.44, height: 1.1),
          textScaler: TextScaler.noScaling,
        ),
      ),
    );

    if (!unlocked) {
      medal = Stack(
        clipBehavior: Clip.none,
        children: [
          medal,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_rounded,
                size: size * 0.2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    } else if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      medal = medal
          .animate()
          .scale(
            begin: const Offset(0.6, 0.6),
            duration: 700.ms,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: 200.ms);
    }

    return Semantics(
      label: title,
      value: unlocked ? '✓' : '🔒',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size + 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                medal,
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: unlocked
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
