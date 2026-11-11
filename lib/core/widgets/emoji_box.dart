import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Emoji on a soft tinted rounded square (circle when [circle] is true).
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
        color: color.withValues(alpha: isDark ? 0.22 : 0.14),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.5, height: 1.1),
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}
