import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Emoji on a soft tinted rounded square (circle when [circle] is true).
/// Design 2.0: a gentle diagonal tint gradient instead of a flat fill.
class EmojiBox extends StatelessWidget {
  const EmojiBox({
    super.key,
    required this.emoji,
    this.color = AppColors.primary,
    this.size = 48,
    this.circle = false,
  });

  final String emoji;
  final Color color;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: isDark ? 0.30 : 0.20),
            color.withValues(alpha: isDark ? 0.14 : 0.08),
          ],
        ),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.5, height: 1.1),
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}
